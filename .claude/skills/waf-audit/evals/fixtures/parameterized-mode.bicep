// Eval fixture: PARAMETERIZED WAF MODE — mode cannot be resolved (no default, simulates EV2 token)
// Expected standalone risk classification: INFO (Parameterized/Unknown + Non-compliant + None detected = row 11b)
// With confirmed upload context: CRITICAL (row 11)
// Tests rows 11/11a/11b of the risk matrix

@description('Name of the WAF policy')
param wafPolicyName string

@description('WAF mode — set at deploy time via EV2 token, no default')
param wafMode string

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
      ]
    }
  }
}
