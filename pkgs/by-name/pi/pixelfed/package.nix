{
  lib,
  fetchFromGitHub,
  php,
  nixosTests,
  nix-update-script,
  dataDir ? "/var/lib/pixelfed",
  runtimeDir ? "/run/pixelfed",
}:
let
  php' = php.withExtensions ({ enabled, all }: enabled ++ (with all; [ ffi redis ]));
in
php'.buildComposerProject2 (finalAttrs: {
  pname = "pixelfed";
  # 0.15.5 will require php >=8.4
  version = "0.15.2";

  src = fetchFromGitHub {
    owner = "pixelfed";
    repo = "pixelfed";
    tag = "v${finalAttrs.version}";
    hash = "sha256-50SjsCPCNmErBfAe0dYl0bpaWoJ3v2qikABcpCgEkmQ=";
  };

  vendorHash = "sha256-QCfbArftb6+SZXsvaDET/IyyyaSV+HosU9ckBrnnm3s=";
  postInstall = ''
    chmod -R u+w $out/share
    mv "$out/share/php/pixelfed"/* $out
    rm -R $out/bootstrap/cache
    # Move static contents for the NixOS module to pick it up, if needed.
    mv $out/bootstrap $out/bootstrap-static

    sed -i 's#instanceof AuthenticationException#instanceof AuthenticationException) {error_log($e->getTraceAsString());//#' $out/bootstrap-static/app.php

    sed -i 's#OAuthServerException::class#//OAuthServerException::class#' $out/bootstrap-static/app.php
    sed -i 's#catch (OAuthServerException#catch (OAuthServerException $e) { echo $e->getMessage() . ($e->getTraceAsString());//#' $out/vendor/laravel/passport/src/Http/Middleware/ValidateToken.php
    sed -i 's#ScopeFactoryInterface $scopeFactory#?ScopeFactoryInterface $scopeFactory#' $out/vendor/pixelfed/fractal/src/Manager.php
    sed -i 's#Scope $parentScopeInstance#?Scope $parentScopeInstance#' $out/vendor/pixelfed/fractal/src/Manager.php
    mv $out/storage $out/storage-static
    ln -s ${dataDir}/.env $out/.env
    ln -s ${dataDir}/storage $out/
    ln -s ${dataDir}/storage/app/public $out/public/storage
    ln -s ${runtimeDir} $out/bootstrap
    chmod +x $out/artisan
  '';

  passthru = {
    tests = { inherit (nixosTests.pixelfed) standard; };
    updateScript = nix-update-script { };
  };

  meta = {
    description = "Federated image sharing platform";
    license = lib.licenses.agpl3Only;
    homepage = "https://pixelfed.org/";
    teams = with lib.teams; [ ngi ];
    platforms = php.meta.platforms;
  };
})
