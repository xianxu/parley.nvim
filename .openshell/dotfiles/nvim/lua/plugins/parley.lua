return {
	"xianxu/parley.nvim",
	-- tag = "v1.8.0",
	-- dir = "~/workspace/parley.nvim",
	-- name = "parley.nvim", -- optional, but can be helpful
	-- dev = true, -- optional, disables some caching features
	config = function()
		local conf = {
			-- For customization, refer to Install > Configuration in the Documentation/Readme
			api_keys = {
				openai = {
					"security",
					"find-generic-password",
					"-a",
					"lovchatvol@gmail.com:neovim",
					"-s",
					"OPENAI_API_KEY",
					"-w",
				},
				anthropic = {
					"security",
					"find-generic-password",
					"-a",
					"lovchatvol@gmail.com:neovim",
					"-s",
					"ANTHROPIC_API_KEY",
					"-w",
				},
				googleai = {
					"security",
					"find-generic-password",
					"-a",
					"lovchatvol@gmail.com:neovim",
					"-s",
					"GOOGLEAI_API_KEY",
					"-w",
				},
				ollama = "dummy_secret",
				cliproxyapi = "kknd",
			},
			-- google_drive = {
			-- 	-- lovchatvol@gmail.com
			-- 	client_id = require("parley.obfuscate").decode(
			-- 		"4459415e5c401953514a5d474811060419081b595208175c1d571308451d15175c00141d0b0202020d010a151a030614021a58021f0e1500000c5e021611061811150f0642061640",
			-- 		"parley-gdrive"
			-- 	),
			-- 	client_secret = require("parley.obfuscate").decode(
			-- 		"372e313f3521000e0b1a0f5b292a102b1a08307d2c223c3000271b36310b3209424a3b",
			-- 		"parley-gdrive"
			-- 	),
			-- 	scopes = { "https://www.googleapis.com/auth/drive.readonly" },
			-- },
			-- oauth = {
			-- 	google = {
			-- 		-- xian@xldigit.com
			-- 		client_id = require("parley.obfuscate").decode(
			-- 			"4254415d564a1a54524b5d4f4845534a580816415417115d4e51190b03055415590b0314591e000656155c0641030614021a58021f0e1500000c5e021611061811150f0642061640",
			-- 			"parley-gdrive"
			-- 		),
			-- 		client_secret = require("parley.obfuscate").decode(
			-- 			"372e313f3521002b3d055e31223b2c432a2a2e7e2b5137081d2f404c3b3c08364a3f53",
			-- 			"parley-gdrive"
			-- 		),
			-- 		scopes = { "https://www.googleapis.com/auth/drive.readonly" },
			-- 	},
			-- 	dropbox = {
			-- 		-- xian@xldigit.com
			-- 		client_id = require("parley.obfuscate").decode("490d055b0e1e5701015901185d4f42", "parley-dropbox"),
			-- 		client_secret = require("parley.obfuscate").decode(
			-- 			"43541a1654004a0d195e03101a4d43",
			-- 			"parley-dropbox"
			-- 		),
			-- 		redirect_port = 53682,
			-- 		scopes = { "sharing.read" },
			-- 	},
			-- 	microsoft = {
			-- 		-- xian@xldigit.com
			-- 		client_id = require("parley.obfuscate").decode(
			-- 			"12561409564c4f5d5e44584259484d1e5f115d0343095d54480b1713021608531a1b5e11",
			-- 			"parley-ms"
			-- 		),
			-- 		client_secret = require("parley.obfuscate").decode(
			-- 			"0020425434077b3b0441311a58374d4a2a202504001b14367f09071b2a0c5b134b41071c41030416",
			-- 			"parley-ms"
			-- 		),
			-- 	},
			-- },
		}
		require("parley").setup(conf)

		-- Setup shortcuts here (see Usage > Shortcuts in the Documentation/Readme)
	end,
}
