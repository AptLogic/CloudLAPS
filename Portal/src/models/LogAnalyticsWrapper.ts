import crypto from 'crypto';
import https from 'https';

/**
 * Wrapper class for sending audit logs to Azure Log Analytics
 * Based on: https://zimmergren.net/building-custom-data-collectors-for-azure-log-analytics/
 */
export class LogAnalyticsWrapper {
  private workspaceId: string;
  private sharedKey: string;
  private logType: string;
  private requestBaseUrl: string;

  constructor(workspaceId: string, sharedKey: string, logType: string) {
    // Validate required parameters
    if (!workspaceId) {
      throw new Error('workspaceId cannot be null or empty');
    }
    if (!sharedKey) {
      throw new Error('sharedKey cannot be null or empty');
    }
    if (!logType) {
      throw new Error('logType cannot be null or empty');
    }

    this.workspaceId = workspaceId;
    this.sharedKey = sharedKey;
    this.logType = logType;
    this.requestBaseUrl = `https://${workspaceId}.ods.opinsights.azure.com/api/logs?api-version=2016-04-01`;
  }

  /**
   * Send a single log entry to Log Analytics
   * @param entity - The log entry object to send
   */
  async sendLogEntry<T>(entity: T): Promise<void> {
    if (!entity) {
      throw new Error("parameter 'entity' cannot be null");
    }

    if (this.logType.length > 100) {
      throw new Error('The size limit for Log-Type parameter is 100 characters.');
    }

    if (!this.isAlphaOnly(this.logType)) {
      throw new Error('Log-Type can only contain alpha characters. It does not support numerics or special characters.');
    }

    await this.sendLogEntries([entity], this.logType);
  }

  /**
   * Send multiple log entries to Log Analytics
   * @param entities - Array of log entry objects to send
   * @param logType - The log type to use
   */
  async sendLogEntries<T>(entities: T[], logType: string): Promise<void> {
    if (!entities || entities.length === 0) {
      throw new Error("parameter 'entities' cannot be null or empty");
    }

    if (logType.length > 100) {
      throw new Error('The size limit for logType parameter is 100 characters.');
    }

    if (!this.isAlphaOnly(logType)) {
      throw new Error('Log-Type can only contain alpha characters.');
    }

    const dateTimeNow = new Date().toUTCString();
    const entityAsJson = JSON.stringify(entities);
    const authSignature = this.getAuthSignature(entityAsJson, dateTimeNow);

    return new Promise((resolve, reject) => {
      const postData = Buffer.from(entityAsJson, 'utf8');

      const options: https.RequestOptions = {
        hostname: `${this.workspaceId}.ods.opinsights.azure.com`,
        path: '/api/logs?api-version=2016-04-01',
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': postData.length,
          'Authorization': authSignature,
          'Log-Type': logType,
          'x-ms-date': dateTimeNow,
          'time-generated-field': '', // Can be extended in the future to support custom date fields
        },
      };

      const req = https.request(options, (res) => {
        let responseData = '';

        res.on('data', (chunk) => {
          responseData += chunk;
        });

        res.on('end', () => {
          if (res.statusCode && res.statusCode >= 200 && res.statusCode < 300) {
            resolve();
          } else {
            reject(
              new Error(
                `Log Analytics returned status ${res.statusCode}: ${responseData}`
              )
            );
          }
        });
      });

      req.on('error', (error) => {
        reject(new Error(`Failed to send log to Analytics: ${error.message}`));
      });

      req.write(postData);
      req.end();
    });
  }

  /**
   * Generate authentication signature for Log Analytics API
   * @param jsonObject - The JSON string to sign
   * @param dateString - The UTC date string
   * @returns The authorization signature
   */
  private getAuthSignature(jsonObject: string, dateString: string): string {
    const stringToSign = `POST\n${jsonObject.length}\napplication/json\nx-ms-date:${dateString}\n/api/logs`;
    const sharedKeyBytes = Buffer.from(this.sharedKey, 'base64');
    const hmac = crypto.createHmac('sha256', sharedKeyBytes);
    hmac.update(stringToSign, 'utf8');
    const signedString = hmac.digest('base64');
    return `SharedKey ${this.workspaceId}:${signedString}`;
  }

  /**
   * Check if string contains only alphabetic characters
   * @param str - The string to validate
   * @returns true if string contains only letters, false otherwise
   */
  private isAlphaOnly(str: string): boolean {
    return /^[a-zA-Z]+$/.test(str);
  }
}
