import { useEffect, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { api } from '../api.js'
import { AvisoError, Ok } from '../components/Aviso.jsx'

const TIPOS = ['tinto', 'blanco', 'rosado', 'espumante']
const VOLUMENES = [187, 375, 750, 1500, 3000]
const VACIO = { nombre_comercial: '', tipo: 'tinto', anada: '', precio: '', graduacion: '', volumen_ml: 750, cuit_bodega: '' }

// Alta (con composicion y maridajes) y edicion de nombre y precio.
// La suma de la composicion la valida la base (RN-05); el front muestra su mensaje.
export default function VinoForm() {
  const { cod } = useParams()
  const editando = Boolean(cod)
  const navigate = useNavigate()
  const [datos, setDatos] = useState(VACIO)
  const [composicion, setComposicion] = useState([{ id_cepa: '', porcentaje: '' }])
  const [maridajesElegidos, setMaridajesElegidos] = useState([])
  const [cepas, setCepas] = useState([])
  const [bodegas, setBodegas] = useState([])
  const [maridajes, setMaridajes] = useState([])
  const [error, setError] = useState(null)
  const [ok, setOk] = useState(null)

  useEffect(() => {
    Promise.all([api.cepas(), api.bodegas(), api.maridajes()])
      .then(([c, b, m]) => { setCepas(c); setBodegas(b); setMaridajes(m) })
      .catch(setError)
  }, [])

  useEffect(() => {
    if (!editando) { setDatos(VACIO); return }
    api.vino(cod).then((v) => setDatos(v)).catch(setError)
  }, [cod, editando])

  const campo = (k) => (e) => setDatos({ ...datos, [k]: e.target.value })
  const cambiarCepa = (i, k) => (e) => setComposicion(composicion.map((c, j) => (j === i ? { ...c, [k]: e.target.value } : c)))
  const alternarMaridaje = (id) =>
    setMaridajesElegidos(maridajesElegidos.includes(id) ? maridajesElegidos.filter((m) => m !== id) : [...maridajesElegidos, id])

  async function guardar(e) {
    e.preventDefault()
    setError(null); setOk(null)
    try {
      if (editando) {
        await api.editarVino(cod, { nombre_comercial: datos.nombre_comercial, precio: datos.precio })
        setOk('Cambios guardados. Si cambió el precio, quedó registrado en la auditoría (RN-13).')
      } else {
        const creado = await api.crearVino({
          ...datos,
          anada: Number(datos.anada),
          volumen_ml: Number(datos.volumen_ml),
          composicion: composicion.map((c) => ({ id_cepa: Number(c.id_cepa), porcentaje: c.porcentaje })),
          maridajes: maridajesElegidos,
        })
        setOk(`Vino creado con el código ${creado.cod_vino}.`)
        setTimeout(() => navigate(`/vinos/${creado.cod_vino}/editar`), 1200)
      }
    } catch (err) {
      setError(err)
    }
  }

  return (
    <>
      <h1>{editando ? 'Editar vino' : 'Nuevo vino'}</h1>
      <p className="sub">
        {editando
          ? 'Se pueden cambiar el nombre y el precio. Cada cambio de precio queda auditado.'
          : 'La composición de cepas tiene que sumar 100 %. Si no, la base rechaza el alta.'}
      </p>

      <form onSubmit={guardar} className="pila" style={{ maxWidth: 760 }}>
        <div className="tarjeta">
          <h2>Datos</h2>
          <div className="grilla-cols">
            <label style={{ gridColumn: 'span 2' }}>Nombre comercial
              <input required value={datos.nombre_comercial} onChange={campo('nombre_comercial')} placeholder="Malbec Reserva" />
            </label>
            <label>Precio
              <input required type="number" step="0.01" value={datos.precio} onChange={campo('precio')} placeholder="12500" />
            </label>
            {!editando && (
              <>
                <label>Tipo
                  <select value={datos.tipo} onChange={campo('tipo')}>{TIPOS.map((t) => <option key={t}>{t}</option>)}</select>
                </label>
                <label>Añada
                  <input required type="number" value={datos.anada} onChange={campo('anada')} placeholder="2022" />
                </label>
                <label>Graduación
                  <input required type="number" step="0.1" value={datos.graduacion} onChange={campo('graduacion')} placeholder="14" />
                </label>
                <label>Volumen
                  <select value={datos.volumen_ml} onChange={campo('volumen_ml')}>{VOLUMENES.map((v) => <option key={v} value={v}>{v} ml</option>)}</select>
                </label>
                <label style={{ gridColumn: 'span 2' }}>Bodega
                  <select required value={datos.cuit_bodega} onChange={campo('cuit_bodega')}>
                    <option value="">Elegí una bodega</option>
                    {bodegas.map((b) => <option key={b.cuit_bodega} value={b.cuit_bodega}>{b.razon_social}</option>)}
                  </select>
                </label>
              </>
            )}
          </div>
        </div>

        {!editando && (
          <>
            <div className="tarjeta">
              <h2>Composición de cepas</h2>
              <div className="pila" style={{ gap: 8 }}>
                {composicion.map((c, i) => (
                  <div className="fila" key={i}>
                    <label style={{ flex: 1 }}>Cepa
                      <select required value={c.id_cepa} onChange={cambiarCepa(i, 'id_cepa')}>
                        <option value="">Elegí una cepa</option>
                        {cepas.map((x) => <option key={x.id_cepa} value={x.id_cepa}>{x.nombre}</option>)}
                      </select>
                    </label>
                    <label style={{ width: 120 }}>Porcentaje
                      <input required type="number" step="0.01" value={c.porcentaje} onChange={cambiarCepa(i, 'porcentaje')} placeholder="60" />
                    </label>
                    <button type="button" disabled={composicion.length === 1} onClick={() => setComposicion(composicion.filter((_, j) => j !== i))}>Quitar</button>
                  </div>
                ))}
              </div>
              <button type="button" style={{ marginTop: 12 }} onClick={() => setComposicion([...composicion, { id_cepa: '', porcentaje: '' }])}>Agregar cepa</button>
            </div>

            <div className="tarjeta">
              <h2>Maridajes</h2>
              <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                {maridajes.map((m) => (
                  <button type="button" key={m.id_maridaje} className="chico"
                    style={maridajesElegidos.includes(m.id_maridaje) ? { background: 'var(--acento-suave)', borderColor: 'var(--acento)', color: 'var(--acento)' } : undefined}
                    onClick={() => alternarMaridaje(m.id_maridaje)}>
                    {m.nombre_maridaje}
                  </button>
                ))}
              </div>
            </div>
          </>
        )}

        <AvisoError error={error} />
        <Ok>{ok}</Ok>
        <div><button className="primario" type="submit">{editando ? 'Guardar cambios' : 'Crear vino'}</button></div>
      </form>
    </>
  )
}
