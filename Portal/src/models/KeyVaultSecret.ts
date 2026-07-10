import { SecretClient } from '@azure/keyvault-secrets';
import { DefaultAzureCredential } from '@azure/identity';

/**
 * Interface representing a Key Vault secret with device information
 */
export interface IKeyVaultSecret {
  secretDeviceName: string;
  secretValue: string;
  secretDate: string;
  secretId: string;
  secretUserName: string;
  secretSerialNumber: string;
  secretAzureADDeviceId: string;
}

/**
 * Class for retrieving and managing device passwords from Azure Key Vault
 */
export class KeyVaultSecret implements IKeyVaultSecret {
  secretDeviceName: string = '';
  secretValue: string = '';
  secretDate: string = '';
  secretId: string = '';
  secretUserName: string = '';
  secretSerialNumber: string = '';
  secretAzureADDeviceId: string = '';

  /**
   * Retrieves a computer's password from Azure Key Vault
   * @param keyVaultUri - The URI of the Azure Key Vault
   * @param searchValue - The serial number or computer name to search for
   * @returns KeyVaultSecret object if found, null otherwise
   */
  static async getComputerAsync(
    keyVaultUri: string,
    searchValue: string
  ): Promise<KeyVaultSecret | null> {
    try {
      // Construct secret client for provided key vault using managed system identity for authentication
      const credential = new DefaultAzureCredential();
      const client = new SecretClient(keyVaultUri, credential);

      // Search for secret with computer name or serial number in Key Vault
      const secretResponse = await client.getSecret(searchValue);
      const secret = secretResponse;

      // Create new instance and populate with secret data
      const keyVaultItem = new KeyVaultSecret();
      
      // Safely extract properties from secret
      keyVaultItem.secretDeviceName = secret.properties.tags?.DeviceName || '';
      keyVaultItem.secretValue = secret.value || '';
      keyVaultItem.secretDate = secret.properties.updatedOn?.toISOString() || '';
      keyVaultItem.secretId = secret.properties.id || '';
      keyVaultItem.secretUserName = secret.properties.tags?.UserName || '';
      keyVaultItem.secretSerialNumber = secret.name || '';
      keyVaultItem.secretAzureADDeviceId = secret.properties.tags?.AzureADDeviceID || '';

      return keyVaultItem;
    } catch (error) {
      // Log error for debugging but return null to indicate secret not found
      if (error instanceof Error) {
        console.error('Error retrieving secret from Key Vault:', error.message);
      } else {
        console.error('Unknown error retrieving secret from Key Vault:', error);
      }
      return null;
    }
  }
}
