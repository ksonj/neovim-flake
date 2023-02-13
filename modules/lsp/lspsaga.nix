{
  pkgs,
  config,
  lib,
  ...
}:
with lib;
with builtins; let
  cfg = config.vim.lsp;
in {
  options.vim.lsp = {lspsaga = {enable = mkEnableOption "LSP Saga";};};

  config = mkIf (cfg.enable && cfg.lspsaga.enable) {
    vim.startPlugins = ["lspsaga"];

    vim.vnoremap = {
      "<silent><leader>sa" = ":<C-U>Lspsaga range_code_action<CR>";
    };

    vim.nnoremap =
      {
        "<silent><leader>sf" = "<cmd>Lspsaga lsp_finder<CR>";
        "<silent><leader>sh" = "<cmd>Lspsaga hover_doc<CR>";
        "<silent><leader>sr" = "<cmd>Lspsaga rename<CR>";
        "<silent><leader>sd" = "<cmd>Lspsaga peek_definition<CR>";
        "<silent><leader>sl" = "<cmd>Lspsaga show_line_diagnostics<CR>";
        "<silent><leader>sc" = "<cmd>Lspsaga show_cursor_diagnostics<CR>";
        "<silent><leader>sp" = "<cmd>Lspsaga diagnostic_jump_prev<CR>";
        "<silent><leader>sn" = "<cmd>Lspsaga diagnostic_jump_next<CR>";
      }
      // (
        if (!cfg.nvimCodeActionMenu.enable)
        then {
          "<silent><leader>sa" = "<cmd>Lspsaga code_action<CR>";
        }
        else {}
      )
      // (
        if (!cfg.lspSignature.enable)
        then {
          "<silent><leader>ss" = "<cmd>Lspsaga signature_help<CR>";
        }
        else {}
      );

    vim.luaConfigRC.lspsaga = nvim.dag.entryAfter ["lsp"] ''
      -- Enable lspsaga
      local saga = require 'lspsaga'
      saga.setup({})
    '';
  };
}
