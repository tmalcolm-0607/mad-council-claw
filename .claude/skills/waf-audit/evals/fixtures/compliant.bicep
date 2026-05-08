// Eval fixture: COMPLIANT — rules 200002 and 200003 properly disabled
// Expected risk classification: OK

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
      requestBodyCheck: 'Enabled'
    }
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'Microsoft_DefaultRuleSet'
          ruleSetVersion: '2.1'
          ruleSetAction: 'Block'
          ruleGroupOverrides: [
            {
              ruleGroupName: 'General'
              rules: [
                {
                  ruleId: '200002'
                  enabledState: 'Disabled'
                }
                {
                  ruleId: '200003'
                  enabledState: 'Disabled'
                }
              ]
            }
          ]
          exclusions: []
        }
      ]
    }
  }
}
