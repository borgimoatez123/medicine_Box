'use client';

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
} from 'react';

export interface DeviceQrPayload {
  medicineBoxId: string;
  deviceId: string;
  deviceToken: string;
}

interface QrTempStoreContextValue {
  getPayload: (medicineBoxId: string) => DeviceQrPayload | null;
  setPayload: (payload: DeviceQrPayload) => void;
  clearPayload: (medicineBoxId: string) => void;
  clearAll: () => void;
}

const QrTempStoreContext = createContext<QrTempStoreContextValue | null>(null);

const STORAGE_KEY = 'smd.device_qr_payloads.v1';

type StorageMap = Record<string, DeviceQrPayload>;

function readStorage(): StorageMap {
  if (typeof window === 'undefined') return {};
  try {
    const raw = window.localStorage.getItem(STORAGE_KEY);
    if (!raw) return {};
    const parsed = JSON.parse(raw) as unknown;
    if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) {
      return parsed as StorageMap;
    }
    return {};
  } catch {
    return {};
  }
}

function writeStorage(map: StorageMap) {
  if (typeof window === 'undefined') return;
  try {
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify(map));
  } catch {
  }
}

export function ProvisionQrTempProvider({
  children,
}: {
  children: React.ReactNode;
}) {
  const storeRef = useRef<Map<string, DeviceQrPayload>>(new Map());
  const storageLoadedRef = useRef(false);
  const [, setTick] = useState(0);

  const hydrateFromStorage = useCallback(() => {
    const fromStorage = readStorage();
    const next = new Map<string, DeviceQrPayload>();
    for (const key of Object.keys(fromStorage)) {
      const entry = fromStorage[key];
      if (
        entry?.medicineBoxId &&
        entry?.deviceId &&
        entry?.deviceToken &&
        typeof entry.medicineBoxId === 'string' &&
        typeof entry.deviceId === 'string' &&
        typeof entry.deviceToken === 'string'
      ) {
        next.set(key, {
          medicineBoxId: entry.medicineBoxId,
          deviceId: entry.deviceId,
          deviceToken: entry.deviceToken,
        });
      }
    }
    storeRef.current = next;
    storageLoadedRef.current = true;
  }, []);

  const getPayload = useCallback((medicineBoxId: string) => {
    return storeRef.current.get(medicineBoxId) ?? null;
  }, []);

  const setPayload = useCallback((payload: DeviceQrPayload) => {
    if (!payload?.medicineBoxId || !payload?.deviceId || !payload?.deviceToken) {
      return;
    }
    storeRef.current.set(payload.medicineBoxId, payload);
    const snapshot = Object.fromEntries(storeRef.current.entries()) as StorageMap;
    writeStorage(snapshot);
    setTick((t) => t + 1);
  }, []);

  const clearPayload = useCallback((medicineBoxId: string) => {
    if (storeRef.current.has(medicineBoxId)) {
      storeRef.current.delete(medicineBoxId);
      const snapshot = Object.fromEntries(storeRef.current.entries()) as StorageMap;
      writeStorage(snapshot);
      setTick((t) => t + 1);
    } else {
      const existing = readStorage();
      if (existing[medicineBoxId]) {
        delete existing[medicineBoxId];
        writeStorage(existing);
        storeRef.current = new Map(
          Object.entries(existing).map(([k, v]) => [k, v as DeviceQrPayload])
        );
        setTick((t) => t + 1);
      }
    }
  }, []);

  const clearAll = useCallback(() => {
    if (storeRef.current.size > 0) {
      storeRef.current.clear();
    }
    writeStorage({});
    setTick((t) => t + 1);
  }, []);

  useEffect(() => {
    if (!storageLoadedRef.current) {
      hydrateFromStorage();
      setTick((t) => t + 1);
    }
    function onStorage(e: StorageEvent) {
      if (e.key === STORAGE_KEY || e.key === null) {
        hydrateFromStorage();
        setTick((t) => t + 1);
      }
    }
    window.addEventListener('storage', onStorage);
    return () => {
      window.removeEventListener('storage', onStorage);
    };
  }, [hydrateFromStorage]);

  const value = useMemo<QrTempStoreContextValue>(
    () => ({ getPayload, setPayload, clearPayload, clearAll }),
    [getPayload, setPayload, clearPayload, clearAll]
  );

  return (
    <QrTempStoreContext.Provider value={value}>
      {children}
    </QrTempStoreContext.Provider>
  );
}

export function useQrTempStore(): QrTempStoreContextValue {
  const ctx = useContext(QrTempStoreContext);
  if (!ctx) {
    return {
      getPayload: () => null,
      setPayload: () => {},
      clearPayload: () => {},
      clearAll: () => {},
    };
  }
  return ctx;
}
