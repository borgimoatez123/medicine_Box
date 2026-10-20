import { QRCodeCanvas } from 'qrcode.react';
import { useRef, useState } from 'react';
import { Download, Printer, Check } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { cn, sanitizeFilenamePart, buildQrPayload } from '@/lib/utils';

export interface DeviceQrPayload {
  deviceId: string;
  deviceToken: string;
}

interface ProvisionQrCodeProps {
  deviceId: string;
  deviceToken: string;
  size?: number;
  includeActions?: boolean;
  className?: string;
}

export default function ProvisionQrCode({
  deviceId,
  deviceToken,
  size = 256,
  includeActions = true,
  className,
}: ProvisionQrCodeProps) {
  const canvasWrapRef = useRef<HTMLDivElement | null>(null);
  const [downloadDone, setDownloadDone] = useState(false);
  const qrPayload = buildQrPayload({ deviceId, deviceToken });

  async function handleDownload() {
    const canvas = canvasWrapRef.current?.querySelector('canvas');
    if (!canvas) return;
    const url = canvas.toDataURL('image/png');
    const a = document.createElement('a');
    a.href = url;
    a.download = `medicine-box-${sanitizeFilenamePart(deviceId)}-qr.png`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    setDownloadDone(true);
    window.setTimeout(() => setDownloadDone(false), 1800);
  }

  function handlePrint() {
    const canvas = canvasWrapRef.current?.querySelector('canvas');
    if (!canvas) return;
    const dataUrl = canvas.toDataURL('image/png');
    const w = window.open('', '_blank', 'width=600,height=700');
    if (!w) return;
    const html = `<!doctype html><html><head><title>QR ${sanitizeFilenamePart(deviceId)}</title><style>
      html,body{margin:0;padding:24px;font-family:system-ui,sans-serif;text-align:center;color:#111}
      .wrap{display:inline-block}
      h1{font-size:18px;margin:0 0 12px}
      .id{font-family:ui-monospace,Menlo,Consolas,monospace;font-size:13px;color:#444;margin:0 0 16px;word-break:break-all}
      img{display:block;margin:0 auto;width:${size}px;height:${size}px;image-rendering:pixelated}
      @media print{body{padding:0}}
      </style></head><body><div class="wrap">
      <h1>Device QR Code</h1>
      <p class="id">${deviceId}</p>
      <img src="${dataUrl}" alt="QR" /></div></body></html>`;
    w.document.write(html);
    w.document.close();
    w.addEventListener('load', () => {
      w.focus();
      setTimeout(() => {
        try {
          w.print();
        } finally {
        }
      }, 150);
    });
  }

  return (
    <div className={cn('flex flex-col items-center gap-4', className)}>
      <Card className="w-full max-w-sm border-dashed">
        <CardContent className="flex flex-col items-center p-6">
          <div ref={canvasWrapRef} className="p-2 bg-white rounded-md">
            <QRCodeCanvas
              value={qrPayload}
              size={size}
              level="M"
              includeMargin
              bgColor="#FFFFFF"
              fgColor="#111827"
            />
          </div>
        </CardContent>
      </Card>
      {includeActions && (
        <div className="flex items-center gap-2">
          <Button variant="outline" size="sm" onClick={handleDownload}>
            {downloadDone ? (
              <>
                <Check className="w-4 h-4 mr-2 text-emerald-600" />
                Downloaded
              </>
            ) : (
              <>
                <Download className="w-4 h-4 mr-2" />
                Download QR
              </>
            )}
          </Button>
          <Button variant="outline" size="sm" onClick={handlePrint}>
            <Printer className="w-4 h-4 mr-2" />
            Print QR
          </Button>
        </div>
      )}
    </div>
  );
}
