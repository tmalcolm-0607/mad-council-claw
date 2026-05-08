// Eval fixture: APP GATEWAY WAF with OWASP CRS — not AFD WAF
// Expected risk classification: ADVISORY (always — App Gateway is a separate concern)
// Tests Phase 2b App Gateway WAF advisory detection

@description('Name of the App Gateway WAF policy')
param wafPolicyName string

resource appGwWafPolicy 'Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies@2024-01-01' = {
  name: wafPolicyName
  location: 'eastus'
  properties: {
    policySettings: {
      requestBodyCheck: true
      maxRequestBodySizeInKb: 128
      fileUploadLimitInMb: 100
      requestBodyInspectLimitInKB: 128
      state: 'Enabled'
      mode: 'Prevention'
      requestBodyEnforcement: true
      fileUploadEnforcement: true
    }
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'OWASP'
          ruleSetVersion: '3.2'
          ruleGroupOverrides: []
        }
        {
          ruleSetType: 'Microsoft_BotManagerRuleSet'
          ruleSetVersion: '1.0'
          ruleGroupOverrides: []
        }
      ]
      exclusions: []
    }
  }
}
