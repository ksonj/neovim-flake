{
  pkgs,
  lib,
  config,
  ...
}:
with lib;
with builtins; let
  cfg = config.vim.copilot;
in {
  options.vim = {
    copilot = {
      enable = mkEnableOption "copilot";
    };
  };
  config =
    mkIf cfg.enable
    {
      vim.startPlugins = ["copilot" "copilot-cmp"];
      vim.luaConfigRC.copilot = nvim.dag.entryAnywhere ''
        require('copilot').setup({
          panel = {
            enabled = false,  -- to not interfere with copilot-cmp
            auto_refresh = false,
            keymap = {
              jump_prev = "[[",
              jump_next = "]]",
              accept = "<CR>",
              refresh = "gr",
              open = "<M-CR>"
            },
            layout = {
              position = "bottom", -- | top | left | right
              ratio = 0.4
            },
          },
          suggestion = {
            enabled = false, -- to not interfere with copilot-cmp
            auto_trigger = false,
            debounce = 75,
            keymap = {
              accept = "<M-l>",
              accept_word = false,
              accept_line = false,
              next = "<M-]>",
              prev = "<M-[>",
              dismiss = "<C-]>",
            },
          },
          filetypes = {
            yaml = false,
            markdown = false,
            help = false,
            gitcommit = false,
            gitrebase = false,
            hgcommit = false,
            svn = false,
            cvs = false,
            ["."] = false,
          },
          copilot_node_command = '${pkgs.nodejs}/bin/node', -- Node.js version must be > 16.x
          server_opts_overrides = {},
        })
      '';
      vim.luaConfigRC.copilot-cmp = nvim.dag.entryAfter ["copilot"] ''
        require('copilot_cmp').setup({
          formatters = {
            insert_text = require("copilot_cmp.format").remove_existing
          },
        })
      '';
    };
}
