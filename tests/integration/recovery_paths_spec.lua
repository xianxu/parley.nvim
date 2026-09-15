local parley=require('parley')
local Helper=require('parley.helper')
local root=vim.fn.tempname()..'-recovery-privacy'
vim.fn.mkdir(root,'p')
parley.setup({chat_dir=root..'/chats',state_dir=root..'/state',providers={},api_keys={},
    agents={{name='Choose a model',disable=true},{name='Fixture',provider='openai',model={model='fixture'},system_prompt='fixture'}}})
local private=root..'/state/answer-recovery'
vim.fn.mkdir(private,'p')
vim.fn.writefile({'PRIVATE_ORIGINAL_ANSWER'},private..'/snapshot.json')
vim.fn.writefile({'PUBLIC_PROFILE_DATA'},root..'/state/other.json')
local uv=vim.uv or vim.loop
assert(uv.fs_symlink(private,root..'/alias'))

describe('recovery artifact input exclusion',function()
    it('refuses direct and symlink-aliased recovery references before any content read',function()
        assert.is_nil(Helper.read_file_content(private..'/snapshot.json'))
        assert.is_nil(Helper.read_file_content(root..'/alias/snapshot.json'))
        assert.equals('PUBLIC_PROFILE_DATA',Helper.read_file_content(root..'/state/other.json'))
    end)
    it('filters private files from broad directory expansion and formatted provider text',function()
        local files=Helper.find_files(root,'*',true)
        for _,file in ipairs(files)do assert.is_nil(file:find('snapshot.json',1,true))end
        local content=Helper.process_directory_pattern(root..'/**/*')
        assert.is_nil(content:find('PRIVATE_ORIGINAL_ANSWER',1,true))
        assert.is_truthy(content:find('PUBLIC_PROFILE_DATA',1,true))
        local payload=parley.dispatcher.prepare_payload({{role='user',content=Helper.format_file_content(private..'/snapshot.json')}},
            {model='fixture'},'openai',{})
        assert.is_nil(vim.json.encode(payload):find('PRIVATE_ORIGINAL_ANSWER',1,true))
    end)
    it('recognizes canonical directories without excluding similarly named siblings',function()
        local Paths=require('parley.recovery_paths')
        assert.equals(uv.fs_realpath(private),uv.fs_realpath(Paths.directory(parley.config.state_dir)))
        assert.is_true(Paths.is_private(root..'/alias/new.json',parley.config.state_dir))
        assert.is_true(Paths.is_private(private,parley.config.state_dir))
        assert.is_false(Paths.is_private(root..'/state/answer-recovery-not-private/file',parley.config.state_dir))
        assert.is_false(Paths.is_private(root..'/state/other.json',parley.config.state_dir))
    end)
    it('keeps explicit recovery attachment bytes out of built messages, payload and logs',function()
        local logs={}
        local parsed=parley.parse_chat({'💬: inspect this','@@'..private..'/snapshot.json@@'},0)
        assert.equals(1,#parsed.exchanges[1].question.file_references)
        local messages=require('parley.chat_respond').build_messages({parsed_chat=parsed,start_index=1,end_index=1,exchange_idx=1,
            config=parley.config,helpers=Helper,agent={name='Fixture',provider='openai',model={model='fixture'},system_prompt='fixture'},
            logger={debug=function(value)logs[#logs+1]=value end,warning=function(value)logs[#logs+1]=value end}})
        local raw=vim.json.encode(parley.dispatcher.prepare_payload(messages,{model='fixture'},'openai',{}))
        assert.is_nil(raw:find('PRIVATE_ORIGINAL_ANSWER',1,true))
        assert.is_truthy(raw:find('Could not read file',1,true))
        assert.is_nil(table.concat(logs,'\n'):find('PRIVATE_ORIGINAL_ANSWER',1,true))
    end)

end)
