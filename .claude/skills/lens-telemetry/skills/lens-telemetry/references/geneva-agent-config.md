# Geneva Monitoring Agent Configuration

When you define a new `IStructuredLogEvent` subclass and register it in your logger, the **code side is only half the story**. Geneva routes log records to named DGrep tables based on the `eventName` declared in the monitoring agent configuration XML, which must exactly match the table name in your `[StructuredEvent("TableName")]` attribute. If the table isn't registered in the monitoring agent, records are silently discarded — nothing appears in DGrep and no error is thrown.

## Adding a new table

In your service's Geneva monitoring agent configuration XML, locate the `<OneDSProviders>` block and add an `<Event>` entry for each new structured event type:

```xml
<MonitoringManagement>
  <Accounts>
    <!-- your accounts config -->
  </Accounts>
  <OneDSProviders>
    <!-- Built-in LENS tables — already present if you copied from the LENS template -->
    <Event eventName="InboundQOSEvent"  />
    <Event eventName="OutboundQOSEvent" />
    <Event eventName="ExceptionEvent"   />

    <!-- Add your service-specific tables here -->
    <Event eventName="DocumentProcessedEvent" />
    <Event eventName="QuotaExceededEvent"      />
  </OneDSProviders>
</MonitoringManagement>
```

The `eventName` value must exactly match the table name declared in your `[StructuredEvent("TableName")]` attribute — casing included.

## Redeployment

After editing the agent XML, redeploy the Geneva monitoring agent to the service's VMs or containers. The agent does not hot-reload configuration changes. Until redeployment completes, log records for the new event type are silently dropped even though your code is emitting them correctly.

## Verifying delivery

Once the agent is redeployed, trigger a request that exercises the new event and check DGrep for the table. A record should appear within a few minutes. If it doesn't:

1. Confirm the `eventName` in the XML matches the `[StructuredEvent]` attribute exactly.
2. Confirm `[StructuredEventLogger]` is applied to your `sealed partial` logger subclass so the generator emits `LogEvent` overloads and populates `CategoryTableMappings`.
3. Confirm `AddLensTelemetry<TLogger>` is called with your subclass as the type argument.
4. Check that `LogEvent(new YourEvent { ... })` is being reached at runtime (add a temporary log statement before the call).

## Built-in tables

The three events pre-registered by `LensStructuredLogger` require no additional setup — their table entries are shipped in the LENS monitoring agent baseline:

| Event class | DGrep table |
|---|---|
| `InboundQOSEvent` | `InboundQOSEvent` |
| `OutboundQOSEvent` | `OutboundQOSEvent` |
| `ExceptionEvent` | `ExceptionEvent` |
