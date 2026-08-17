local pr = require("parley.pair_return")

describe("parley.pair_return", function()
	describe("is_composer_active", function()
		it("active when cursor visible and >=2 painted rows near cursor", function()
			local state = {
				rows = 38, cols = 120,
				cursorRow = 20, cursorCol = 3, cursorVisible = true,
				paintedRows = { [19]=true, [20]=true, [21]=true },
			}
			assert.is_true(pr.is_composer_active(state))
		end)

		it("active at logical bottom (38 rows out of 38)", function()
			local state = {
				rows = 38, cols = 120,
				cursorRow = 36, cursorCol = 3, cursorVisible = true,
				paintedRows = { [35]=true, [36]=true, [37]=true },
			}
			assert.is_true(pr.is_composer_active(state))
		end)

		it("inactive when cursor hidden", function()
			local state = {
				rows = 38, cols = 120,
				cursorRow = 20, cursorCol = 3, cursorVisible = false,
				paintedRows = { [19]=true, [20]=true },
			}
			assert.is_false(pr.is_composer_active(state))
		end)

		it("inactive when no painted rows near cursor", function()
			local state = {
				rows = 38, cols = 120,
				cursorRow = 20, cursorCol = 3, cursorVisible = true,
				paintedRows = {},
			}
			assert.is_false(pr.is_composer_active(state))
		end)

		it("inactive when paint away from cursor", function()
			local state = {
				rows = 38, cols = 120,
				cursorRow = 20, cursorCol = 3, cursorVisible = true,
				paintedRows = { [10]=true, [11]=true },
			}
			assert.is_false(pr.is_composer_active(state))
		end)

		it("inactive with only one nearby row (sparse)", function()
			local state = {
				rows = 38, cols = 120,
				cursorRow = 20, cursorCol = 3, cursorVisible = true,
				paintedRows = { [10]=true, [20]=true },
			}
			assert.is_false(pr.is_composer_active(state))
		end)

		it("inactive when rows/cols zero", function()
			local state = {
				rows = 0, cols = 0,
				cursorRow = 20, cursorCol = 3, cursorVisible = true,
				paintedRows = { [19]=true, [20]=true },
			}
			assert.is_false(pr.is_composer_active(state))
		end)
	end)

	describe("should_rewrite", function()
		it("rewrites when composer active, cursor visible, no overlay", function()
			assert.is_true(pr.should_rewrite({ cursorVisible=true, composerActive=true, overlayActive=false }))
		end)

		it("bypass when overlay active even if composer active", function()
			assert.is_false(pr.should_rewrite({ cursorVisible=true, composerActive=true, overlayActive=true }))
		end)

		it("bypass when cursor hidden", function()
			assert.is_false(pr.should_rewrite({ cursorVisible=false, composerActive=true, overlayActive=false }))
		end)

		it("bypass when composer inactive", function()
			assert.is_false(pr.should_rewrite({ cursorVisible=true, composerActive=false, overlayActive=false }))
		end)

		it("bypass when unknown composer (nil)", function()
			assert.is_false(pr.should_rewrite({ cursorVisible=true, composerActive=nil, overlayActive=false }))
		end)
	end)

	describe("cr_keys with gate", function()
		it("composer inactive → bare CR even with no popup", function()
			local gate = { cursorVisible=true, composerActive=false, overlayActive=false }
			assert.equals("<CR>", pr.cr_keys(false, false, nil, gate))
		end)

		it("composer inactive → bare CR plus base (interview)", function()
			local gate = { cursorVisible=true, composerActive=false, overlayActive=false }
			assert.equals("<CR><CR>:05min ", pr.cr_keys(false, false, "<CR><CR>:05min ", gate))
		end)

		it("hidden cursor → bare CR", function()
			local gate = { cursorVisible=false, composerActive=true, overlayActive=false }
			assert.equals("<CR>", pr.cr_keys(false, false, nil, gate))
		end)

		it("overlay active → bare CR beats composer", function()
			local gate = { cursorVisible=true, composerActive=true, overlayActive=true }
			assert.equals("<CR>", pr.cr_keys(false, false, nil, gate))
			assert.equals("<C-y>", pr.cr_keys(true, true, nil, { cursorVisible=true, composerActive=true, overlayActive=false }))
		end)

		it("composer active + no popup → base", function()
			local gate = { cursorVisible=true, composerActive=true, overlayActive=false }
			assert.equals("<CR>", pr.cr_keys(false, false, nil, gate))
			assert.equals("<CR><CR>:05min ", pr.cr_keys(false, false, "<CR><CR>:05min ", gate))
		end)

		it("composer active + popup selection → <C-y>", function()
			local gate = { cursorVisible=true, composerActive=true, overlayActive=false }
			assert.equals("<C-y>", pr.cr_keys(true, true, nil, gate))
		end)

		it("composer active + popup no selection → <C-e>base", function()
			local gate = { cursorVisible=true, composerActive=true, overlayActive=false }
			assert.equals("<C-e><CR>", pr.cr_keys(true, false, nil, gate))
			assert.equals("<C-e><CR><CR>:05min ", pr.cr_keys(true, false, "<CR><CR>:05min ", gate))
		end)

		it("no gate supplied → back-compat popup logic", function()
			assert.equals("<CR>", pr.cr_keys(false, false, nil, nil))
			assert.equals("<C-y>", pr.cr_keys(true, true, nil, nil))
			assert.equals("<C-e><CR>", pr.cr_keys(true, false, nil, nil))
		end)
	end)
end)
