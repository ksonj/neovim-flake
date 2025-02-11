{
  pkgs,
  config,
  lib,
  ...
}:
with lib;
with builtins; let
  vcfg = config.vim;
  cfg = config.vim.lsp;
  black-and-isort = pkgs.writeShellApplication {
    name = "black";
    text = ''
      black --quiet - "$@" | isort --profile black -
    '';
    runtimeInputs = [pkgs.python310Packages.black pkgs.python310Packages.isort];
  };
  black =
    if cfg.python.sortImports
    then black-and-isort
    else pkgs.black;
in {
  options.vim.lsp = {
    enable = mkEnableOption "neovim lsp support";
    formatOnSave = mkEnableOption "Format on save";
    nix = {
      enable = mkEnableOption "Nix LSP";
      server = mkOption {
        type = with types; enum ["rnix" "nil"];
        default = "nil";
        description = "Which LSP to use";
      };

      pkg = mkOption {
        type = types.package;
        default =
          if (cfg.nix.server == "rnix")
          then pkgs.rnix-lsp
          else pkgs.nil;
        description = "The LSP package to use";
      };

      formatter = mkOption {
        type = with types; enum ["nixpkgs-fmt" "alejandra"];
        default = "nixpkgs-fmt";
        description = "Which nix formatter to use";
      };
    };
    rust = {
      enable = mkEnableOption "Rust LSP";
      rustAnalyzerOpts = mkOption {
        type = types.str;
        default = ''
          ["rust-analyzer"] = {
            experimental = {
              procAttrMacros = true,
            },
          },
        '';
        description = "options to pass to rust analyzer";
      };
    };
    python = {
      enable = mkEnableOption "Python LSP";
      sortImports = mkOption {
        type = types.bool;
        default = true;
        description = "Sort imports on format";
      };
    };
    clang = {
      enable = mkEnableOption "C language LSP";
      c_header = mkEnableOption "C syntax header files";
      cclsOpts = mkOption {
        type = types.str;
        default = "";
      };
    };
    sql = mkEnableOption "SQL Language LSP";
    go = mkEnableOption "Go language LSP";
    ts = mkEnableOption "TS language LSP";
    zig.enable = mkEnableOption "Zig language LSP";
    scala = {
      enable = mkEnableOption "Scala LSP";
      metals = mkOption {
        type = types.package;
        default = pkgs.metals;
        description = "The Metals package to use. Default pkgs.metals.";
      };
    };
  };

  config = mkIf cfg.enable (
    let
      writeIf = cond: msg:
        if cond
        then msg
        else "";
    in {
      vim.startPlugins =
        [
          "nvim-lspconfig"
          "null-ls"
          (
            if (config.vim.autocomplete.enable && (config.vim.autocomplete.type == "nvim-cmp"))
            then "cmp-nvim-lsp"
            else null
          )
          (
            if cfg.sql
            then "sqls-nvim"
            else null
          )
        ]
        ++ (
          if cfg.rust.enable
          then [
            "crates-nvim"
            "rust-tools"
          ]
          else []
        )
        ++ (
          if cfg.scala.enable
          then [
            "nvim-metals"
          ]
          else []
        );

      vim.configRC.lsp = nvim.dag.entryAnywhere ''
        ${
          if cfg.nix.enable
          then ''
            autocmd filetype nix setlocal tabstop=2 shiftwidth=2 softtabstop=2
          ''
          else ""
        }

        ${
          if cfg.clang.c_header
          then ''
            " c syntax for header (otherwise breaks treesitter highlighting)
            " https://www.reddit.com/r/neovim/comments/orfpcd/question_does_the_c_parser_from_nvimtreesitter/
            let g:c_syntax_for_h = 1
          ''
          else ""
        }
      '';
      vim.luaConfigRC.lsp = let
        opts = desc: "{ noremap=true, silent=true, desc='${desc}'}";
      in
        nvim.dag.entryAnywhere
        ''
          ${
            if vcfg.keys.whichKey.enable
            then ''
              local _wk = require("which-key")
              _wk.register({
                ["<leader>l"] = {
                  name = "+lsp",
                  g = {
                    name = "+goto",
                  },
                  w = {
                    name = "+workspace",
                  }
                }
              })
            ''
            else ""
          }
          local format_scala = function()
            vim.lsp.buf.format()
          end

          local attach_keymaps = function(client, bufnr)
            vim.api.nvim_buf_set_keymap(bufnr, 'n', '<leader>lgD', '<cmd>lua vim.lsp.buf.declaration()<CR>', ${opts "Declaration"})
            vim.api.nvim_buf_set_keymap(bufnr, 'n', '<leader>lgd', '<cmd>lua vim.lsp.buf.definition()<CR>', ${opts "Definition"})
            vim.api.nvim_buf_set_keymap(bufnr, 'n', '<leader>lgt', '<cmd>lua vim.lsp.buf.type_definition()<CR>', ${opts "Type definition"})
            vim.api.nvim_buf_set_keymap(bufnr, 'n', '<leader>lgn', '<cmd>lua vim.diagnostic.goto_next()<CR>', ${opts "Next diagnostic"})
            vim.api.nvim_buf_set_keymap(bufnr, 'n', '<leader>lgp', '<cmd>lua vim.diagnostic.goto_prev()<CR>', ${opts "Previous diagnostic"})

            vim.api.nvim_buf_set_keymap(bufnr, 'n', '<leader>lwa', '<cmd>lua vim.lsp.buf.add_workspace_folder()<CR>', ${opts "Add workspace folder"})
            vim.api.nvim_buf_set_keymap(bufnr, 'n', '<leader>lwr', '<cmd>lua vim.lsp.buf.remove_workspace_folder()<CR>', ${opts "Remove workspace folder"})
            vim.api.nvim_buf_set_keymap(bufnr, 'n', '<leader>lwl', '<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<CR>', ${opts "List workspace folders"})
            vim.api.nvim_buf_set_keymap(bufnr, 'n', '<leader>le', '<cmd>lua vim.diagnostic.open_float()<CR>', ${opts "Diagnostics float"})
            vim.api.nvim_buf_set_keymap(bufnr, 'n', '<leader>lh', '<cmd>lua vim.lsp.buf.hover()<CR>', ${opts "Hover"})
            vim.api.nvim_buf_set_keymap(bufnr, 'n', '<leader>ls', '<cmd>lua vim.lsp.buf.signature_help()<CR>', ${opts "Signature help"})
            vim.api.nvim_buf_set_keymap(bufnr, 'n', '<leader>ln', '<cmd>lua vim.lsp.buf.rename()<CR>', ${opts "Rename"})
            vim.api.nvim_buf_set_keymap(bufnr, 'n', '<leader>lf', '<cmd>lua vim.lsp.buf.format({ async=true })<CR>', ${opts "Format"})
          end

          local null_ls = require("null-ls")
          local null_helpers = require("null-ls.helpers")
          local null_methods = require("null-ls.methods")

          local ls_sources = {
            ${writeIf cfg.python.enable
            ''
              null_ls.builtins.formatting.black.with({
                command = "${black}/bin/black",
              }),
            ''}

            -- Commented out for now
            --${writeIf (config.vim.git.enable && config.vim.git.gitsigns.enable) ''
            --  null_ls.builtins.code_actions.gitsigns,
            --''}

            ${writeIf cfg.sql
            ''
              null_helpers.make_builtin({
                method = null_methods.internal.FORMATTING,
                filetypes = { "sql" },
                generator_opts = {
                  to_stdin = true,
                  ignore_stderr = true,
                  suppress_errors = true,
                  command = "${pkgs.sqlfluff}/bin/sqlfluff",
                  args = {
                    "fix",
                    "-",
                  },
                },
                factory = null_helpers.formatter_factory,
              }),

              null_ls.builtins.diagnostics.sqlfluff.with({
                command = "${pkgs.sqlfluff}/bin/sqlfluff",
                extra_args = {"--dialect", "postgres"}
              }),
            ''}

            ${writeIf
            (cfg.nix.enable
              && cfg.nix.server == "rnix"
              && cfg.nix.formatter == "alejandra")
            ''
              null_ls.builtins.formatting.alejandra.with({
                command = "${pkgs.alejandra}/bin/alejandra"
              }),
            ''}

              null_ls.builtins.formatting.prettier.with({
                command = "${pkgs.nodePackages.prettier}/bin/prettier"
              }),
            ${writeIf cfg.ts
            ''
              null_ls.builtins.diagnostics.eslint,
            ''}
          }

          vim.g.formatsave = ${
            if cfg.formatOnSave
            then "true"
            else "false"
          };

          -- Enable formatting
          format_callback = function(client, bufnr)
            vim.api.nvim_create_autocmd("BufWritePre", {
              group = augroup,
              buffer = bufnr,
              callback = function()
                if vim.g.formatsave then
                  if client.supports_method("textDocument/formatting") then
                    local params = require'vim.lsp.util'.make_formatting_params({})
                    client.request('textDocument/formatting', params, nil, bufnr)
                  end
                end
              end
            })
          end

          default_on_attach = function(client, bufnr)
            attach_keymaps(client, bufnr)
            format_callback(client, bufnr)
          end

          -- Enable null-ls
          require('null-ls').setup({
            diagnostics_format = "[#{m}] #{s} (#{c})",
            debounce = 250,
            default_timeout = 5000,
            sources = ls_sources,
            on_attach=default_on_attach,
            debug=false
          })

          -- Enable lspconfig
          local lspconfig = require('lspconfig')

          local capabilities = vim.lsp.protocol.make_client_capabilities()
          ${
            let
              cfg = config.vim.autocomplete;
            in
              writeIf cfg.enable (
                if cfg.type == "nvim-cmp"
                then ''
                  capabilities = require('cmp_nvim_lsp').default_capabilities()
                ''
                else ""
              )
          }

          ${writeIf cfg.rust.enable ''
            -- Rust config
            local rt = require('rust-tools')

            rust_on_attach = function(client, bufnr)
              default_on_attach(client, bufnr)
              local olpts = { noremap=true, silent=true, buffer = bufnr }
              vim.keymap.set("n", "<leader>ris", rt.inlay_hints.set, opts)
              vim.keymap.set("n", "<leader>riu", rt.inlay_hints.unset, opts)
              vim.keymap.set("n", "<leader>rr", rt.runnables.runnables, opts)
              vim.keymap.set("n", "<leader>rp", rt.parent_module.parent_module, opts)
              vim.keymap.set("n", "<leader>rm", rt.expand_macro.expand_macro, opts)
              vim.keymap.set("n", "<leader>rc", rt.open_cargo_toml.open_cargo_toml, opts)
              vim.keymap.set("n", "<leader>rg", function() rt.crate_graph.view_crate_graph("x11", nil) end, opts)
            end

            local rustopts = {
              tools = {
                autoSetHints = true,
                hover_with_actions = false,
                inlay_hints = {
                  only_current_line = false,
                }
              },
              server = {
                capabilities = capabilities,
                on_attach = rust_on_attach,
                cmd = {"${pkgs.rust-analyzer}/bin/rust-analyzer"},
                settings = {
                  ${cfg.rust.rustAnalyzerOpts}
                }
              }
            }

            require('crates').setup {
              null_ls = {
                enabled = true,
                name = "crates.nvim",
              }
            }
            rt.setup(rustopts)
          ''}

          ${optionalString cfg.zig.enable ''
            -- Zig config
            lspconfig.zls.setup {
              capabilities = capabilities,
              on_attach=default_on_attach,
              cmd = {"${pkgs.zls}/bin/zls"},
              settings = {
                ["zls"] = {
                  zig_exe_path = "${pkgs.zig}/bin/zig",
                  zig_lib_path = "${pkgs.zig}/lib/zig",
                }
              }
            }
          ''}

          ${writeIf cfg.python.enable ''
            -- Python config
            lspconfig.pyright.setup{
              capabilities = capabilities,
              on_attach=default_on_attach,
              cmd = {"${pkgs.nodePackages.pyright}/bin/pyright-langserver", "--stdio"}
              }
          ''}

          ${
            writeIf cfg.scala.enable ''
              -- Scala config
              -- Scala nvim-metals config
              scala_attach = function(client, bufnr)
                default_on_attach(client, bufnr)
                vim.api.nvim_buf_set_keymap(bufnr, 'n', '<leader>lf', '<cmd>MetalsOrganizeImports<cr><cmd>lua vim.lsp.buf.format({ async=true })<CR>', ${opts "Format"})
              end
              metals_config = require('metals').bare_config()
              metals_config.capabilities = capabilities
              metals_config.on_attach = scala_attach
              metals_config.settings = {
                 metalsBinaryPath = "${cfg.scala.metals}/bin/metals",
                 showImplicitArguments = true,
                 excludedPackages = {
                   "akka.actor.typed.javadsl",
                   "com.github.swagger.akka.javadsl"
                 }
              }
              metals_config.handlers["textDocument/publishDiagnostics"] = vim.lsp.with(
                vim.lsp.diagnostic.on_publish_diagnostics, {
                  virtual_text = {
                    prefix = '',
                  }
                }
              )
              -- without doing this, autocommands that deal with filetypes prohibit messages from being shown
              vim.opt_global.shortmess:remove("F")
              vim.cmd([[augroup lsp]])
              vim.cmd([[autocmd!]])
              vim.cmd([[autocmd FileType java,scala,sbt lua require('metals').initialize_or_attach(metals_config)]])
              vim.cmd([[augroup end]])
            ''
          }

          ${writeIf cfg.nix.enable (
            (writeIf (cfg.nix.server == "rnix") ''
              -- Nix (rnix) config
              lspconfig.rnix.setup{
                capabilities = capabilities,
                ${writeIf (cfg.nix.formatter == "alejandra")
                ''
                  on_attach = function(client, bufnr)
                    attach_keymaps(client, bufnr)
                  end,
                ''}
                ${writeIf (cfg.nix.formatter == "nixpkgs-fmt")
                ''
                  on_attach = default_on_attach,
                ''}
                cmd = {"${cfg.nix.pkg}/bin/rnix-lsp"},
              }
            '')
            + (writeIf (cfg.nix.server == "nil") ''
              -- Nix (nil) config
              lspconfig.nil_ls.setup{
                capabilities = capabilities,
                on_attach=default_on_attach,
                cmd = {"${cfg.nix.pkg}/bin/nil"},
                settings = {
                  ["nil"] = {
                ${writeIf (cfg.nix.formatter == "alejandra")
                ''
                  formatting = {
                    command = {"${pkgs.alejandra}/bin/alejandra", "--quiet"},
                  },
                ''}
                ${writeIf (cfg.nix.formatter == "nixpkgs-fmt")
                ''
                  formatting = {
                    command = {"${pkgs.nixpkgs-fmt}/bin/nixpkgs-fmt"},
                  },
                ''}
                  },
                };
              }
            '')
          )}


          ${writeIf cfg.clang.enable ''
            -- CCLS (clang) config
            lspconfig.ccls.setup{
              capabilities = capabilities;
              on_attach=default_on_attach;
              cmd = {"${pkgs.ccls}/bin/ccls"};
              ${
              if cfg.clang.cclsOpts == ""
              then ""
              else "init_options = ${cfg.clang.cclsOpts}"
            }
            }
          ''}

          ${writeIf cfg.sql ''
            -- SQLS config
            lspconfig.sqls.setup {
              on_attach = function(client)
                client.server_capabilities.execute_command = true
                on_attach_keymaps(client, bufnr)
                require'sqls'.setup{}
              end,
              cmd = {"${pkgs.sqls}/bin/sqls", "-config", string.format("%s/config.yml", vim.fn.getcwd()) }
            }
          ''}

          ${writeIf cfg.go ''
            -- Go config
            lspconfig.gopls.setup {
              capabilities = capabilities;
              on_attach = default_on_attach;
              cmd = {"${pkgs.gopls}/bin/gopls", "serve"},
            }
          ''}

          ${writeIf cfg.ts ''
            -- TS config
            lspconfig.tsserver.setup {
              capabilities = capabilities;
              on_attach = function(client, bufnr)
                attach_keymaps(client, bufnr)
              end,
              cmd = { "${pkgs.nodePackages.typescript-language-server}/bin/typescript-language-server", "--stdio" }
            }
          ''}
        '';
    }
  );
}
