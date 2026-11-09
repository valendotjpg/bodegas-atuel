// Unica capa que habla con la API. La URL base se configura con VITE_API_URL
// (por defecto /api: nginx en Docker o el proxy de Vite en desarrollo).
const BASE = import.meta.env.VITE_API_URL ?? '/api'

export class ApiError extends Error {
  constructor(status, body) {
    super(mensajeDeError(body, status))
    this.status = status
    this.sqlstate = body?.sqlstate ?? null
  }
}

// Muestra el mensaje tal como lo devuelve la API (incluidas las reglas de la base).
function mensajeDeError(body, status) {
  if (!body) return `Error ${status}`
  if (typeof body.detail === 'string') return body.detail
  if (Array.isArray(body.detail)) {
    return body.detail.map((d) => `${d.loc?.slice(1).join('.') || 'dato'}: ${d.msg}`).join(' · ')
  }
  return `Error ${status}`
}

async function request(method, path, { params, body } = {}) {
  const query = params
    ? '?' + new URLSearchParams(Object.entries(params).filter(([, v]) => v !== '' && v != null)).toString()
    : ''
  const response = await fetch(`${BASE}${path}${query}`, {
    method,
    headers: body ? { 'Content-Type': 'application/json' } : undefined,
    body: body ? JSON.stringify(body) : undefined,
  })
  if (response.status === 204) return null
  const data = await response.json().catch(() => null)
  if (!response.ok) throw new ApiError(response.status, data)
  return data
}

export const api = {
  // Catalogos
  cepas: () => request('GET', '/cepas'),
  bodegas: () => request('GET', '/bodegas'),
  maridajes: () => request('GET', '/maridajes'),
  salas: () => request('GET', '/salas'),
  depositos: () => request('GET', '/depositos'),

  // Vinos
  vinos: (params) => request('GET', '/vinos', { params }),
  vino: (cod) => request('GET', `/vinos/${cod}`),
  crearVino: (body) => request('POST', '/vinos', { body }),
  editarVino: (cod, body) => request('PUT', `/vinos/${cod}`, { body }),

  // Clientes y ventas
  clientes: (params) => request('GET', '/clientes', { params }),
  crearComprobante: (body) => request('POST', '/comprobantes', { body }),

  // Transferencias
  transferencias: (params) => request('GET', '/transferencias', { params }),
  transferencia: (nro) => request('GET', `/transferencias/${nro}`),
  crearTransferencia: (id_sala) => request('POST', '/transferencias', { body: { id_sala } }),
  agregarRenglon: (nro, body) => request('POST', `/transferencias/${nro}/renglones`, { body }),
  terminarTransferencia: (nro) => request('POST', `/transferencias/${nro}/terminar`),
  procesarTransferencia: (nro, deposit_id) =>
    request('POST', `/transferencias/${nro}/procesar`, { params: { deposit_id } }),

  // Reportes
  topVinos: () => request('GET', '/reportes/top-vinos'),
  ventasPorSala: () => request('GET', '/reportes/ventas-por-sala'),
  vinosSinStock: (id_sala) => request('GET', '/reportes/vinos-sin-stock', { params: { id_sala } }),
}
