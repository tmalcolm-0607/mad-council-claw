// Eval fixture: DETECTION MODE + PARTIAL OVERRIDE — only rule 200002 disabled in Detection mode
// Expected risk classification: MEDIUM (if confirmed upload service) or LOW (if unknown)
// Tests rows 9/9a/9b of the risk matrix

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
      mode: 'Detection'
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
                // Note: 200003 is NOT disabled — single trigger (score=5) would block in Prevention mode
              ]
            }
          ]
          exclusions: []
        }
      ]
    }
  }
}
