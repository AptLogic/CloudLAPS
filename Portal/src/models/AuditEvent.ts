/**
 * Interface representing an audit event for Log Analytics
 */
export interface AuditEvent {
  AzureADDeviceId: string;
  UserPrincipalName: string;
  ComputerName: string;
  SerialNumber: string;
  Action: string;
  CreatedOn: string;
  Result: string;
  Id: string;
}
