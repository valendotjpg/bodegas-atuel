import { useEffect, useState } from 'react'
import { api } from '../api.js'
import { AvisoError, pesos } from '../components/Aviso.jsx'

// La venta se manda completa (cabecera y renglones) en una sola transaccion.
// Precio, descuento, stock y totales los resuelve la base: el front solo muestra la respuesta.
export default function Venta() {
  const [salas, setSalas] = useState([])
  const [sala, setSala] = useState('')
  const [busquedaCliente, setBusquedaCliente] = useState('')
  const [clientes, setClientes] = useState([])
  const [cliente, setCliente] = useState(null)
  const [busquedaVino, setBusquedaVino] = useState('')
  const [vinos, setVinos] = useState([])
  const [renglones, setRenglones] = useState([])
  const [resultado, setResultado] = useState(null)
  const [nombres, setNombres] = useState({})
  const [error, setError] = useState(null)
  const [enviando, setEnviando] = useState(false)

  useEffect(() => { api.salas().then(setSalas).catch(setError) }, [])

  useEffect(() => {
    if (busquedaCliente.length < 2) { setClientes([]); return }
    const t = setTimeout(() => api.clientes({ q: busquedaCliente, limit: 8 }).then(setClientes).catch(setError), 250)
    return () => clearTimeout(t)
  }, [busquedaCliente])

  useEffect(() => {
    if (busquedaVino.length < 2) { setVinos([]); return }
    const t = setTimeout(() => api.vinos({ q: busquedaVino, limit: 8 }).then(setVinos).catch(setError), 250)
    return () => clearTimeout(t)
  }, [busquedaVino])

  const nombreCliente = (c) => c.razon_social || `${c.apellido}, ${c.nombre}`

  function agregarVino(v) {
    if (!renglones.some((r) => r.cod_vino === v.cod_vino)) {
      setRenglones([...renglones, { cod_vino: v.cod_vino, nombre: v.nombre_comercial, cantidad: 1 }])
    }
    setBusquedaVino(''); setVinos([])
  }

  const cambiarCantidad = (cod, valor) =>
    setRenglones(renglones.map((r) => (r.cod_vino === cod ? { ...r, cantidad: valor } : r)))

  async function vender() {
    setError(null); setResultado(null); setEnviando(true)
    try {
      const r = await api.crearComprobante({
        id_sala: Number(sala),
        id_cliente: cliente.id_cliente,
        renglones: renglones.map((x) => ({ cod_vino: x.cod_vino, cantidad: Number(x.cantidad) })),
      })
      setNombres(Object.fromEntries(renglones.map((x) => [x.cod_vino, x.nombre])))
      setResultado(r)
      setRenglones([])
    } catch (err) {
      setError(err)
    } finally {
      setEnviando(false)
    }
  }

  const listo = sala && cliente && renglones.length > 0

  return (
    <>
      <h1>Nueva venta</h1>
      <p className="sub">Elegí la sala y el cliente, agregá los vinos y confirmá. El total lo calcula la base.</p>

      <div className="grilla-2">
        <div className="pila">
          <div className="tarjeta">
            <h2>Sala y cliente</h2>
            <div className="grilla-cols">
              <label>Sala
                <select value={sala} onChange={(e) => setSala(e.target.value)}>
                  <option value="">Elegí una sala</option>
                  {salas.map((s) => <option key={s.id_sala} value={s.id_sala}>{s.id_sala} · {s.localidad} ({s.calle} {s.numero})</option>)}
                </select>
              </label>
              <label>Cliente
                <input value={cliente ? nombreCliente(cliente) : busquedaCliente}
                  onChange={(e) => { setCliente(null); setBusquedaCliente(e.target.value) }}
                  placeholder="Buscá por nombre o documento" />
              </label>
            </div>
            {!cliente && clientes.length > 0 && (
              <table style={{ marginTop: 8 }}>
                <tbody>
                  {clientes.map((c) => (
                    <tr key={c.id_cliente} className="clic" onClick={() => setCliente(c)}>
                      <td>{nombreCliente(c)}</td><td className="muted">{c.tipo_documento} {c.nro_documento}</td><td><span className="chip">{c.tipo_cliente}</span></td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
            {cliente && <p className="muted" style={{ margin: '8px 0 0' }}>Cliente {cliente.tipo_cliente}: la base aplica su descuento.</p>}
          </div>

          <div className="tarjeta">
            <h2>Vinos</h2>
            <label>Agregar vino
              <input value={busquedaVino} onChange={(e) => setBusquedaVino(e.target.value)} placeholder="Buscá por nombre, por ejemplo Reserva" />
            </label>
            {vinos.length > 0 && (
              <table style={{ marginTop: 8 }}>
                <tbody>
                  {vinos.map((v) => (
                    <tr key={v.cod_vino} className="clic" onClick={() => agregarVino(v)}>
                      <td>{v.nombre_comercial}</td><td className="muted">{v.volumen_ml} ml</td><td className="num">{pesos(v.precio)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}

            {renglones.length > 0 && (
              <table style={{ marginTop: 16 }}>
                <thead><tr><th>Vino</th><th style={{ width: 120 }}>Cantidad</th><th /></tr></thead>
                <tbody>
                  {renglones.map((r) => (
                    <tr key={r.cod_vino}>
                      <td>{r.nombre}</td>
                      <td><input type="number" min="1" value={r.cantidad} onChange={(e) => cambiarCantidad(r.cod_vino, e.target.value)} style={{ width: 90 }} /></td>
                      <td className="num"><button className="chico" onClick={() => setRenglones(renglones.filter((x) => x.cod_vino !== r.cod_vino))}>Quitar</button></td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
            {renglones.length === 0 && <div className="vacio">Todavía no agregaste vinos</div>}
          </div>

          <AvisoError error={error} />
          <div><button className="primario" disabled={!listo || enviando} onClick={vender}>{enviando ? 'Registrando…' : 'Confirmar venta'}</button></div>
        </div>

        <div className="tarjeta">
          <h2>Comprobante</h2>
          {!resultado && <div className="vacio">Acá aparece el comprobante calculado por la base</div>}
          {resultado && (
            <>
              <p className="muted" style={{ marginTop: -6 }}>N.° {resultado.comprobante.nro_comprobante} · {resultado.comprobante.fecha} · sala {resultado.comprobante.id_sala}</p>
              <table>
                <thead><tr><th>Vino</th><th className="num">Cant.</th><th className="num">Precio</th><th className="num">Desc.</th><th className="num">Subtotal</th></tr></thead>
                <tbody>
                  {resultado.renglones.map((r) => (
                    <tr key={r.cod_vino}>
                      <td>{nombres[r.cod_vino] ?? r.cod_vino}</td><td className="num">{r.cantidad}</td><td className="num">{pesos(r.precio_unitario)}</td>
                      <td className="num">{Number(r.descuento_aplicado)} %</td><td className="num">{pesos(r.subtotal_renglon)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
              <div className="totales">
                <div className="metrica"><span>Subtotal</span><strong>{pesos(resultado.comprobante.subtotal)}</strong></div>
                <div className="metrica"><span>Descuento</span><strong>{pesos(resultado.comprobante.descuento)}</strong></div>
                <div className="metrica"><span>Total</span><strong style={{ color: 'var(--acento)' }}>{pesos(resultado.comprobante.total)}</strong></div>
              </div>
            </>
          )}
        </div>
      </div>
    </>
  )
}
