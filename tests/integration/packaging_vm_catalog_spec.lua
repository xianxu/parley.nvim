local probe = dofile('tests/packaging/vm_chat.lua')
describe('VM acceptance model discovery', function()
    it('queries model-owning providers when healthy Codex has no models', function()
        local calls = {}
        local accounts = {
            codex = {healthy = true, models = {}},
            google = {healthy = true, models = {'vision-model'}},
        }
        local proxy = {
            credential_health_for_login = function(provider, done)
                done({state = accounts[provider] and 'healthy' or 'absent'})
            end,
            list_models = function(provider, done)
                assert.is_not_nil(require('parley.cliproxy_config').provider_owned_by(provider))
                calls[#calls + 1] = provider
                done(accounts[provider].models)
            end,
        }
        local model, healthy = probe.live_model(proxy)
        assert.equals('vision-model', model)
        assert.is_true(healthy)
        assert.same({'codex', 'google'}, calls)
        accounts.google = nil
        model, healthy = probe.live_model(proxy)
        assert.is_nil(model)
        assert.is_true(healthy)
    end)
end)
