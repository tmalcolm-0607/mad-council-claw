// Eval fixture: BODY CHECK DISABLED — requestBodyCheck is off, rules 200002/200003 never fire
// Expected risk classification: OK (body check off — rules inactive)
// Note: disabling body check entirely is a security trade-off; flag in report

@description('Name of the WAF policy')
param wafPolicyName string

resource wafPolicy 'Microsoft.Network/FrontDoorWebApplicationFirewallPolicies@2024-02-01' = {
  name: wafPolicyName
  location: 'Global'
  sku: {
    name: 'Premium_AzureFrontDoor'
  }
  properties: {
    policySettings: {
      enabledState: 'Enabled'
      mode: 'Prevention'
      requestBodyCheck: 'Disabled'
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
      ]
    }
  }
}
