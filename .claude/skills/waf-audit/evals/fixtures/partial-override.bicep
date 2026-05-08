// Eval fixture: PARTIAL — only rule 200002 disabled, 200003 still active
// Expected risk classification: CRITICAL (confirmed upload) or HIGH (unknown upload) — one rule still active in Prevention mode

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
                // Note: 200003 is NOT disabled — single trigger (score=5) blocks the request
              ]
            }
          ]
          exclusions: []
        }
      ]
    }
  }
}
