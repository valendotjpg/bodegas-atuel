// Muestra el error tal como lo devuelve la API, con su SQLSTATE si lo trae.
export function AvisoError({ error }) {
  if (!error) return null
  return (
    <div className="aviso error" role="alert">
      {error.message}
      {error.sqlstate && <span className="codigo">SQLSTATE {error.sqlstate}</span>}
    </div>
  )
}

export function Ok({ children }) {
  if (!children) return null
  return <div className="aviso ok">{children}</div>
}

// Formato de moneda solo para mostrar; los importes los calcula la base.
export const pesos = (n) =>
  n == null ? '' : Number(n).toLocaleString('es-AR', { style: 'currency', currency: 'ARS' })
