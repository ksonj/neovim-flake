{
  pkgs,
  lib,
  config,
  ...
}:
with lib;
with builtins; let
  cfg = config.vim.surround;
in {
  options.vim = {
    surround = {
      enable = mkEnableOption "nvim-surround";
    };
  };
  config =
    mkIf cfg.enable
    {
      vim.startPlugins = ["nvim-surround"];

      vim.luaConfigRC.surround = nvim.dag.entryAnywhere ''
        require("nvim-surround").setup{}
      '';
    };
}
