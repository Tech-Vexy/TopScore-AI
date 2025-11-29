declare module '@react-native-community/netinfo' {
  export interface NetInfoState {
    type: string;
    isConnected: boolean | null;
    isInternetReachable: boolean | null;
    isWifiEnabled?: boolean;
    details: any;
  }

  export interface NetInfoSubscription {
    (): void;
  }

  export interface NetInfoConfiguration {
    reachabilityUrl?: string;
    reachabilityTest?: (response: Response) => Promise<boolean>;
    reachabilityLongTimeout?: number;
    reachabilityShortTimeout?: number;
    reachabilityRequestTimeout?: number;
    shouldFetchWiFiSSID?: boolean;
    useNativeReachability?: boolean;
  }

  export function addEventListener(
    listener: (state: NetInfoState) => void
  ): NetInfoSubscription;

  export function fetch(requestedInterface?: string): Promise<NetInfoState>;

  export function configure(params: NetInfoConfiguration): void;

  const NetInfo: {
    addEventListener: typeof addEventListener;
    fetch: typeof fetch;
    configure: typeof configure;
  };

  export default NetInfo;
}
