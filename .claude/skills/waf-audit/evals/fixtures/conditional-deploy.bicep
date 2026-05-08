// Eval fixture: CONDITIONAL DEPLOY — WAF template exists but is gated behind a false flag
// Expected risk classification: DEFERRED
// This file simulates a main.bicep that conditionally deploys a WAF module

@description('Instance name prefix')
param instanceName string

// Front Door is not yet enabled for this service
var shouldDeployFrontDoor = false

var wafPolicyName = '${instanceName}-waf'

// The WAF policy below would be non-compliant if deployed,
// but since shouldDeployFrontDoor = false, it is DEFERRED.
resource wafPolicy 'Microsoft.Network/FrontDoorWebApplicationFirewallPolicies@2025-03-01' = if (shouldDeployFrontDoor) {
  name: wafPolicyName
  location: 'Global'
  sku: {
    name: 'Premium_AzureFrontDoor'
  }
  properties: {
    policySettings: {
      enabledState: 'Enabled'
      mode: 'Detection'
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
