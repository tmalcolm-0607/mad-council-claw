// Eval fixture: DETECTION MODE — WAF is log-only, rules not overridden
// Expected risk classification: MEDIUM (if confirmed upload service) or LOW (if unknown)
// Note: ruleSetAction: 'Block' is overridden to log-only by Detection mode

@description('Name of the WAF policy')
param wafPolicyName string

@description('WAF mode')
@allowed(['Detection', 'Prevention'])
param wafMode string = 'Detection'

resource wafPolicy 'Microsoft.Network/FrontDoorWebApplicationFirewallPolicies@2024-02-01' = {
  name: wafPolicyName
  location: 'Global'
  sku: {
    name: 'Premium_AzureFrontDoor'
  }
  properties: {
    policySettings: {
      enabledState: 'Enabled'
      mode: wafMode
      requestBodyCheck: 'Enabled'
    }
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'Microsoft_DefaultRuleSet'
          ruleSetVersion: '2.1'
          ruleSetAction: 'Block'
          ruleGroupOverrides: []
          exclusions: []
        }
        {
          ruleSetType: 'Microsoft_BotManagerRuleSet'
          ruleSetVersion: '1.1'
          ruleSetAction: 'Block'
          ruleGroupOverrides: []
          exclusions: []
        }
      ]
    }
  }
}
