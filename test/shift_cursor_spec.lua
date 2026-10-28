local helpers = require("test.helpers")

describe("Bullets.vim", function()
  describe("shifting a line", function()
    before_each(function()
      helpers.reset_config()
      vim.opt.expandtab = true
      vim.opt.shiftwidth = 2
      vim.opt.tabstop = 8
      vim.opt.shiftround = false
    end)

    it("never enters operator-pending mode or visits column 1", function()
      helpers.new_buffer({ "- one", "- two words here" })
      vim.api.nvim_win_set_cursor(0, { 2, 6 }) -- on "words"
      local modes, cols = {}, {}
      local group = vim.api.nvim_create_augroup("bullets_shift_spec", { clear = true })
      vim.api.nvim_create_autocmd("ModeChanged", {
        group = group,
        callback = function()
          table.insert(modes, vim.v.event.new_mode)
        end,
      })
      vim.api.nvim_create_autocmd("CursorMoved", {
        group = group,
        callback = function()
          table.insert(cols, vim.fn.col("."))
        end,
      })
      vim.cmd("BulletDemote")
      vim.api.nvim_del_augroup_by_id(group)
      assert.are.same({ "- one", "  * two words here" }, helpers.get_lines())
      for _, m in ipairs(modes) do
        assert.is_falsy(m:match("^no"), "entered " .. m)
      end
      for _, c in ipairs(cols) do
        assert.are_not.equal(1, c)
      end
      -- the cursor stays on the same text
      assert.are.same({ 2, 8 }, vim.api.nvim_win_get_cursor(0))
    end)

    it("keeps the cursor on its text when the shift is undone", function()
      helpers.new_buffer({ "- one", "- two words here" })
      vim.api.nvim_win_set_cursor(0, { 2, 6 })
      helpers.feedkeys(">>")
      helpers.feedkeys("u")
      assert.are.same({ "- one", "- two words here" }, helpers.get_lines())
      assert.are.same({ 2, 6 }, vim.api.nvim_win_get_cursor(0))
    end)

    it("matches >> and << for spaces, tabs, shiftround and blank lines", function()
      local function check(opts, line, dir)
        for k, v in pairs(opts) do
          vim.opt[k] = v
        end
        -- what Vim's own operator gives on a plain buffer
        vim.cmd("enew")
        vim.bo.filetype = "nobullets"
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { line })
        vim.cmd("normal! " .. (dir > 0 and ">>" or "<<"))
        local want = vim.api.nvim_buf_get_lines(0, 0, -1, false)
        -- the plugin's shift of a non-bullet line is the shift alone
        helpers.new_buffer({ line })
        vim.cmd(dir > 0 and "BulletDemote" or "BulletPromote")
        assert.are.same(want, helpers.get_lines())
      end
      check({ expandtab = true, shiftwidth = 4, shiftround = false }, "   text", 1)
      check({ expandtab = true, shiftwidth = 4, shiftround = true }, "   text", 1)
      check({ expandtab = true, shiftwidth = 4, shiftround = true }, "     text", -1)
      check({ expandtab = true, shiftwidth = 4, shiftround = false }, "  text", -1)
      check({ expandtab = false, shiftwidth = 4, tabstop = 8, shiftround = false }, "\t  text", 1)
      check({ expandtab = false, shiftwidth = 4, tabstop = 4, shiftround = false }, "\ttext", -1)
      check({ expandtab = true, shiftwidth = 2, shiftround = false }, "", 1)
    end)
  end)
end)
