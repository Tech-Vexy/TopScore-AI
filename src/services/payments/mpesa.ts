import { httpsCallable, getFunctions } from 'firebase/functions';
import app from '../firebase/config';

const functions = getFunctions(app);

export const initiateMpesaPayment = async (phoneNumber: string, amount: number, resourceId: string) => {
  try {
    // In a real app, this would call a Cloud Function
    // const initiateStkPush = httpsCallable(functions, 'initiateStkPush');
    // const result = await initiateStkPush({ phoneNumber, amount, resourceId });
    // return result.data;

    // Simulation for demo
    console.log(`Initiating M-Pesa payment of KES ${amount} for ${resourceId} to ${phoneNumber}`);
    return new Promise((resolve) => {
      setTimeout(() => {
        resolve({
          checkoutRequestId: 'ws_CO_DMZ_123456789',
          merchantRequestId: '12345-67890-12345',
          responseCode: '0',
          responseDescription: 'Success. Request accepted for processing',
          customerMessage: 'Success. Request accepted for processing'
        });
      }, 2000);
    });
  } catch (error) {
    console.error("M-Pesa payment initiation failed:", error);
    throw error;
  }
};
