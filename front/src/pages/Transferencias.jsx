import { useCallback, useEffect, useState } from 'react'
import { api } from '../api.js'
import { AvisoError, Ok } from '../components/Aviso.jsx'

const ESTADOS = { en_confeccion: 'En confección', terminado: 'Terminado', procesado: 'Procesado' }

// Crear, cargar renglones y avanzar de estado. Los botones se habilitan segun el estado
// actual; igual, la base es la que valida (RN-10, RN-11, RN-12) y su mensaje se muestra.
export default function Transferencias() {
  const [salas, setSalas] = useState([])
  const [depositos, setDepositos] = useState([])
  const [filtroEstado, setFiltroEstado] = useState('')
  const [lista, setLista] = useState([])
  const [elegida, setElegida] = useState(null)
  const [salaNueva, setSalaNueva] = useState('')
  const [deposito, setDeposito] = useState('')
  const [busquedaVino, setBusquedaVino] = useState('')
  const [vinos, setVinos] = useState([])
  const [cantidad, setCantidad] = useState(10)
  const [error, setError] = useState(null)
  const [ok, setOk] = useState(null)

  useEffect(() => {
    Promise.all([api.salas(), api.depositos()])
      .then(([s, d]) => { setSalas(s); setDepositos(d); setDeposito(d[0]?.id_deposito ?? '') })
      .catch(setError)
  }, [])

  const cargarLista = useCallback(
    () => api.transferencias({ estado: filtroEstado, limit: 15 }).then(setLista).catch(setError),
    [filtroEstado],
  )
  useEffect(() => { cargarLista() }, [cargarLista])

  useEffect(() => {
    if (busquedaVino.length < 2) { setVinos([]); return }
    const t = setTimeout(() => api.vinos({ q: busquedaVino, limit: 6 }).then(setVinos).catch(setError), 250)
    return () => clearTimeout(t)
  }, [busquedaVino])

  const abrir = (nro) => api.transferencia(nro).then((t) => { setElegida(t); setError(null) }).catch(setError)

  // Ejecuta una accion, muestra el mensaje y refresca el detalle y la lista.
  async function accion(fn, mensaje) {
    setError(null); setOk(null)
    try {
      const r = await fn()
      if (mensaje) setOk(mensaje)
      const nro = r?.nro_solicitud ?? elegida?.nro_solicitud
      if (nro) await abrir(nro)
      await cargarLista()
    } catch (err) {
      setError(err)
      if (elegida) await abrir(elegida.nro_solicitud)
    }
  }

  const estado = elegida?.estado

  return (
    <>
      <h1>Transferencias</h1>
      <p className="sub">Del depósito central a las salas: se crea, se cargan los vinos, se termina y se procesa.</p>

      <div className="grilla-2">
        <div className="pila">
          <div className="tarjeta">
            <h2>Nueva transferencia</h2>
            <div className="fila">
              <label style={{ flex: 1 }}>Sala destino
                <select value={salaNueva} onChange={(e) => setSalaNueva(e.target.value)}>
                  <option value="">Elegí una sala</option>
                  {salas.map((s) => <option key={s.id_sala} value={s.id_sala}>{s.id_sala} · {s.localidad}</option>)}
                </select>
              </label>
              <button className="primario" disabled={!salaNueva}
                onClick={() => accion(() => api.crearTransferencia(Number(salaNueva)), 'Transferencia creada en confección.')}>
                Crear
              </button>
            </div>
          </div>

          <div className="tarjeta">
            <div className="fila" style={{ justifyContent: 'space-between', marginBottom: 8 }}>
              <h2 style={{ margin: 0 }}>Últimas transferencias</h2>
              <select value={filtroEstado} onChange={(e) => setFiltroEstado(e.target.value)} style={{ width: 170 }}>
                <option value="">Todos los estados</option>
                {Object.entries(ESTADOS).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
              </select>
            </div>
            <table>
              <thead><tr><th>N.°</th><th>Fecha</th><th>Sala</th><th className="num">Botellas</th><th>Estado</th></tr></thead>
              <tbody>
                {lista.map((t) => (
                  <tr key={t.nro_solicitud} className={`clic ${elegida?.nro_solicitud === t.nro_solicitud ? 'elegida' : ''}`} onClick={() => abrir(t.nro_solicitud)}>
                    <td>{t.nro_solicitud}</td><td>{t.fecha}</td><td>{t.id_sala}</td><td className="num">{t.botellas}</td>
                    <td><span className={`estado ${t.estado}`}>{ESTADOS[t.estado]}</span></td>
                  </tr>
                ))}
              </tbody>
            </table>
            {lista.length === 0 && <div className="vacio">No hay transferencias</div>}
          </div>
        </div>

        <div className="pila">
          <div className="tarjeta">
            {!elegida && <div className="vacio">Elegí o creá una transferencia</div>}
            {elegida && (
              <>
                <div className="fila" style={{ justifyContent: 'space-between' }}>
                  <h2 style={{ margin: 0 }}>Transferencia {elegida.nro_solicitud}</h2>
                  <span className={`estado ${estado}`}>{ESTADOS[estado]}</span>
                </div>
                <p className="muted">Sala {elegida.id_sala} · confeccionada el {elegida.fecha}</p>

                <table style={{ marginBottom: 12 }}>
                  <thead><tr><th>Vino</th><th className="num">Cantidad</th></tr></thead>
                  <tbody>
                    {elegida.renglones.map((r) => <tr key={r.cod_vino}><td>{r.nombre_comercial}</td><td className="num">{r.cantidad}</td></tr>)}
                  </tbody>
                </table>
                {elegida.renglones.length === 0 && <div className="vacio">Sin renglones todavía</div>}

                <div className="pila" style={{ gap: 8 }}>
                  <label>Agregar vino {estado !== 'en_confeccion' && <span>(solo en confección)</span>}
                    <input value={busquedaVino} onChange={(e) => setBusquedaVino(e.target.value)} placeholder="Buscá por nombre" disabled={estado !== 'en_confeccion'} />
                  </label>
                  {vinos.length > 0 && (
                    <div className="fila">
                      <input type="number" min="1" value={cantidad} onChange={(e) => setCantidad(e.target.value)} style={{ width: 90 }} />
                      {vinos.map((v) => (
                        <button key={v.cod_vino} className="chico"
                          onClick={() => { setBusquedaVino(''); accion(() => api.agregarRenglon(elegida.nro_solicitud, { cod_vino: v.cod_vino, cantidad: Number(cantidad) }), 'Renglón agregado.') }}>
                          {v.nombre_comercial}
                        </button>
                      ))}
                    </div>
                  )}
                </div>

                <div className="fila" style={{ marginTop: 16, borderTop: '1px solid var(--borde)', paddingTop: 16 }}>
                  <button disabled={estado !== 'en_confeccion'}
                    onClick={() => accion(() => api.terminarTransferencia(elegida.nro_solicitud), 'Transferencia terminada.')}>
                    Terminar
                  </button>
                  <select value={deposito} onChange={(e) => setDeposito(e.target.value)} style={{ width: 170 }} disabled={estado !== 'terminado'}>
                    {depositos.map((d) => <option key={d.id_deposito} value={d.id_deposito}>{d.nombre}</option>)}
                  </select>
                  <button className="primario" disabled={estado !== 'terminado'}
                    onClick={() => accion(() => api.procesarTransferencia(elegida.nro_solicitud, deposito), 'Transferencia procesada: el stock pasó del depósito a la sala.')}>
                    Procesar
                  </button>
                </div>
              </>
            )}
          </div>
          <AvisoError error={error} />
          <Ok>{ok}</Ok>
        </div>
      </div>
    </>
  )
}
