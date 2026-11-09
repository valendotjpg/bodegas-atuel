import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { api } from '../api.js'
import { AvisoError, pesos } from '../components/Aviso.jsx'

const POR_PAGINA = 15
const TIPOS = ['tinto', 'blanco', 'rosado', 'espumante']

export default function Catalogo() {
  const [cepas, setCepas] = useState([])
  const [bodegas, setBodegas] = useState([])
  const [filtros, setFiltros] = useState({ tipo: '', id_cepa: '', cuit_bodega: '', anada: '' })
  const [pagina, setPagina] = useState(0)
  const [vinos, setVinos] = useState([])
  const [elegido, setElegido] = useState(null)
  const [error, setError] = useState(null)

  useEffect(() => {
    Promise.all([api.cepas(), api.bodegas()])
      .then(([c, b]) => { setCepas(c); setBodegas(b) })
      .catch(setError)
  }, [])

  // Paginado en la base: se pide una fila de mas para saber si hay pagina siguiente.
  useEffect(() => {
    api.vinos({ ...filtros, limit: POR_PAGINA + 1, offset: pagina * POR_PAGINA })
      .then((v) => { setVinos(v); setError(null) })
      .catch(setError)
  }, [filtros, pagina])

  const cambiar = (campo) => (e) => { setPagina(0); setFiltros({ ...filtros, [campo]: e.target.value }) }
  const ver = (cod) => api.vino(cod).then(setElegido).catch(setError)

  return (
    <>
      <h1>Catálogo de vinos</h1>
      <p className="sub">Filtrá por tipo, cepa, bodega o añada. Tocá un vino para ver su composición.</p>

      <div className="tarjeta" style={{ marginBottom: 20 }}>
        <div className="grilla-cols">
          <label>Tipo
            <select value={filtros.tipo} onChange={cambiar('tipo')}>
              <option value="">Todos</option>
              {TIPOS.map((t) => <option key={t} value={t}>{t}</option>)}
            </select>
          </label>
          <label>Cepa
            <select value={filtros.id_cepa} onChange={cambiar('id_cepa')}>
              <option value="">Todas</option>
              {cepas.map((c) => <option key={c.id_cepa} value={c.id_cepa}>{c.nombre}</option>)}
            </select>
          </label>
          <label>Bodega
            <select value={filtros.cuit_bodega} onChange={cambiar('cuit_bodega')}>
              <option value="">Todas</option>
              {bodegas.map((b) => <option key={b.cuit_bodega} value={b.cuit_bodega}>{b.razon_social}</option>)}
            </select>
          </label>
          <label>Añada
            <input type="number" min="1990" max="2100" placeholder="2022" value={filtros.anada} onChange={cambiar('anada')} />
          </label>
        </div>
      </div>

      <AvisoError error={error} />

      <div className="grilla-2" style={{ marginTop: error ? 16 : 0 }}>
        <div className="tarjeta">
          <table>
            <thead>
              <tr><th>Vino</th><th>Tipo</th><th>Añada</th><th className="num">Precio</th></tr>
            </thead>
            <tbody>
              {vinos.slice(0, POR_PAGINA).map((v) => (
                <tr key={v.cod_vino} className={`clic ${elegido?.cod_vino === v.cod_vino ? 'elegida' : ''}`} onClick={() => ver(v.cod_vino)}>
                  <td><div style={{ fontWeight: 500 }}>{v.nombre_comercial}</div><div className="muted">{v.bodega} · {v.volumen_ml} ml</div></td>
                  <td><span className={`chip ${v.tipo === 'tinto' ? 'acento' : ''}`}>{v.tipo}</span></td>
                  <td>{v.anada}</td>
                  <td className="num">{pesos(v.precio)}</td>
                </tr>
              ))}
            </tbody>
          </table>
          {vinos.length === 0 && <div className="vacio">No hay vinos con esos filtros</div>}
          <div className="paginado">
            <button disabled={pagina === 0} onClick={() => setPagina(pagina - 1)}>Anterior</button>
            <span className="muted">Página {pagina + 1}</span>
            <button disabled={vinos.length <= POR_PAGINA} onClick={() => setPagina(pagina + 1)}>Siguiente</button>
          </div>
        </div>

        <div className="tarjeta">
          {!elegido && <div className="vacio">Elegí un vino de la lista</div>}
          {elegido && (
            <>
              <h2>{elegido.nombre_comercial}</h2>
              <p className="muted" style={{ marginTop: -6 }}>{elegido.bodega} · {elegido.tipo} · {elegido.anada} · {elegido.volumen_ml} ml · {elegido.graduacion}°</p>
              <p style={{ fontSize: 20, fontWeight: 600, margin: '8px 0 16px' }}>{pesos(elegido.precio)}</p>
              <h2>Composición</h2>
              <table style={{ marginBottom: 16 }}>
                <tbody>
                  {elegido.composicion.map((c) => (
                    <tr key={c.id_cepa}><td>{c.nombre}</td><td className="num">{Number(c.porcentaje)} %</td></tr>
                  ))}
                </tbody>
              </table>
              <h2>Maridajes</h2>
              <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', marginBottom: 16 }}>
                {elegido.maridajes.length === 0 && <span className="muted">Sin maridajes</span>}
                {elegido.maridajes.map((m) => <span key={m.id_maridaje} className="chip">{m.nombre}</span>)}
              </div>
              <Link to={`/vinos/${elegido.cod_vino}/editar`}><button>Editar vino</button></Link>
            </>
          )}
        </div>
      </div>
    </>
  )
}
