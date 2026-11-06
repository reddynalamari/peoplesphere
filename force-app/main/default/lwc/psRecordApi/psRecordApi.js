/**
 * Record editor API: inside Salesforce calls PS_RecordEditorController,
 * on the public HR demo calls the password-protected PS_GuestHrGateway.
 */
import isGuest from '@salesforce/user/isGuest';
import describeObject from '@salesforce/apex/PS_RecordEditorController.describeObject';
import getRecord from '@salesforce/apex/PS_RecordEditorController.getRecord';
import saveRecord from '@salesforce/apex/PS_RecordEditorController.saveRecord';
import deleteRecord from '@salesforce/apex/PS_RecordEditorController.deleteRecord';
import searchLookup from '@salesforce/apex/PS_RecordEditorController.searchLookup';
import hr_describeObject from '@salesforce/apex/PS_GuestHrGateway.describeObject';
import hr_getRecord from '@salesforce/apex/PS_GuestHrGateway.getRecord';
import hr_saveRecord from '@salesforce/apex/PS_GuestHrGateway.saveRecord';
import hr_deleteRecord from '@salesforce/apex/PS_GuestHrGateway.deleteRecord';
import hr_searchLookup from '@salesforce/apex/PS_GuestHrGateway.searchLookup';
import { withToken } from 'c/psHrAuth';

const API = isGuest
    ? {
          describeObject: withToken(hr_describeObject),
          getRecord: withToken(hr_getRecord),
          saveRecord: withToken(hr_saveRecord),
          deleteRecord: withToken(hr_deleteRecord),
          searchLookup: withToken(hr_searchLookup)
      }
    : { describeObject, getRecord, saveRecord, deleteRecord, searchLookup };

export default API;

export function errorMessage(e) {
    if (!e) return 'Unexpected error';
    if (e.body && e.body.message) return e.body.message.replace(/^HR_LOCKED:\s*/, '');
    if (e.body && e.body.pageErrors && e.body.pageErrors.length) return e.body.pageErrors[0].message;
    return e.message || 'Unexpected error';
}
