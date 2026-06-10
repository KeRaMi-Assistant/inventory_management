// Shared FCM-HTTP-v1-Helpers (extrahiert aus send-notifications, Paket 1):
// tracking-poll pusht Status-Wechsel sofort ("Dein Paket ist in Zustellung"),
// send-notifications bleibt der Cron-Pfad für mhd/delivery/payment/low_stock.
//
// Kein Secret-Leak: FCM_SERVICE_ACCOUNT_JSON wird nur via Deno.env gelesen,
// Token/Keys tauchen nie in Logs auf (Caller loggen nur Status-Codes).

export interface ServiceAccount {
  client_email: string
  private_key: string
  project_id: string
}

export interface FcmToken {
  token: string
  platform: string
}

export interface PushPayload {
  title: string
  body: string
  data?: Record<string, string>
}

export function parseServiceAccount(): ServiceAccount | null {
  try {
    const raw = Deno.env.get('FCM_SERVICE_ACCOUNT_JSON') ?? ''
    if (!raw) return null
    const obj = JSON.parse(raw)
    if (!obj.client_email || !obj.private_key || !obj.project_id) return null
    return obj as ServiceAccount
  } catch {
    return null
  }
}

export async function getGoogleAccessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  const claim = {
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  }
  const header = { alg: 'RS256', typ: 'JWT' }
  const enc = (o: unknown) =>
    btoa(JSON.stringify(o)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
  const unsigned = `${enc(header)}.${enc(claim)}`

  const pem = sa.private_key.replace(/\\n/g, '\n')
  const key = await importPkcs8(pem)
  const sigBuf = await crypto.subtle.sign(
    { name: 'RSASSA-PKCS1-v1_5' },
    key,
    new TextEncoder().encode(unsigned),
  )
  const sig = arrayBufferToBase64Url(sigBuf)
  const jwt = `${unsigned}.${sig}`

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  })
  if (!res.ok) throw new Error(`oauth ${res.status}: ${await res.text()}`)
  const data = await res.json()
  return data.access_token as string
}

export async function sendToTokens(
  projectId: string,
  accessToken: string,
  tokens: FcmToken[],
  payload: PushPayload,
): Promise<boolean> {
  let anySuccess = false
  for (const t of tokens) {
    const res = await fetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          message: {
            token: t.token,
            notification: { title: payload.title, body: payload.body },
            data: payload.data ?? {},
            apns: { payload: { aps: { sound: 'default' } } },
            android: { priority: 'high', notification: { sound: 'default' } },
          },
        }),
      },
    )
    if (res.ok) {
      anySuccess = true
    } else {
      console.warn('FCM send failed', t.platform, res.status, await res.text())
    }
  }
  return anySuccess
}

async function importPkcs8(pem: string): Promise<CryptoKey> {
  const b64 = pem
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s+/g, '')
  const buf = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0))
  return crypto.subtle.importKey(
    'pkcs8',
    buf,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  )
}

function arrayBufferToBase64Url(buf: ArrayBuffer): string {
  const bytes = new Uint8Array(buf)
  let binary = ''
  for (let i = 0; i < bytes.byteLength; i++) binary += String.fromCharCode(bytes[i])
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}
