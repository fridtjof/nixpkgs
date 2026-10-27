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

  vendorHash = "sha256-QCfbArftb6+SZXsvaDET/IyyyaSV+HosU9ckBrnnm3s= ";
  postInstall = ''
    chmod -R u+w $out/share
    mv "$out/share/php/pixelfed"/* $out
    rm -R $out/bootstrap/cache
    # Move static contents for the NixOS module to pick it up, if needed.
    mv $out/bootstrap $out/bootstrap-static
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
