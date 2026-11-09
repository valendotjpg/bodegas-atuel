import { useEffect, useState } from 'react'
import { Bar } from 'react-chartjs-2'
import { BarElement, CategoryScale, Chart as ChartJS, LinearScale, Tooltip } from 'chart.js'
import { api } from '../api.js'
import { AvisoError, pesos } from '../components/Aviso.jsx'

ChartJS.register(CategoryScale, LinearScale, BarElement, Tooltip)

// Los tres reportes son consultas de la seccion 8 que corren en la base (S1, S8 y S6).
export default function Tablero() {
  const [top, setTop] = useState([])
  const [ventas, setVentas] = useState([])
  const [salas, setSalas] = useState([])
  const [sala, setSala] = useState('')
  const [sinStock, setSinStock] = useState(null)
  const [error, setError] = useState(null)

  useEffect(() => {
    Promise.all([api.topVinos(), api.ventasPorSala(), api.salas()])
      .then(([t, v, s]) => { setTop(t); setVentas(v); setSalas(s) })
      .catch(setError)
  }, [])

  useEffect(() => {
    if (!sala) { setSinStock(null); return }
    api.vinosSinStock(sala).then(setSinStock).catch(setError)
  }, [sala])

  const datos = {
    labels: ventas.map((v) => `${v.id_sala} · ${v.localidad}`),
    datasets: [{ data: ventas.map((v) => Number(v.total_vendido)), backgroundColor: '#7b2337', borderRadius: 4 }],
  }
  const opciones = {
    indexAxis: 'y',
    maintainAspectRatio: false,
    plugins: { tooltip: { callbacks: { label: (c) => pesos(c.raw) } } },
    scales: { x: { ticks: { callback: (v) => `$ ${(v / 1000).toLocaleString('es-AR')} mil` } }, y: { ticks: { font: { size: 11 } } } },
  }

  return (
    <>
      <h1>Tablero</h1>
      <p className="sub">Ventas y stock de la red de salas.</p>
      <AvisoError error={error} />

      <div className="grilla-2" style={{ marginTop: error ? 16 : 0 }}>
        <div className="tarjeta">
          <h2>Ventas por sala en el último trimestre</h2>
          <div style={{ height: Math.max(320, ventas.length * 22) }}><Bar data={datos} options={opciones} /></div>
        </div>

        <div className="pila">
          <div className="tarjeta">
            <h2>Los 10 vinos más vendidos</h2>
            <table>
              <thead><tr><th>#</th><th>Vino</th><th className="num">Botellas</th></tr></thead>
              <tbody>
                {top.map((v, i) => (
                  <tr key={v.cod_vino}><td className="muted">{i + 1}</td><td>{v.nombre_comercial}</td><td className="num">{Number(v.botellas_vendidas).toLocaleString('es-AR')}</td></tr>
                ))}
              </tbody>
            </table>
          </div>

          <div className="tarjeta">
            <h2>Vinos sin stock en una sala</h2>
            <label>Sala
              <select value={sala} onChange={(e) => setSala(e.target.value)}>
                <option value="">Elegí una sala</option>
                {salas.map((s) => <option key={s.id_sala} value={s.id_sala}>{s.id_sala} · {s.localidad}</option>)}
              </select>
            </label>
            {sinStock && (
              <>
                <p className="muted" style={{ margin: '12px 0 8px' }}>{sinStock.length} vinos sin stock en la sala y con stock en el depósito.</p>
                <div style={{ maxHeight: 260, overflowY: 'auto' }}>
                  <table>
                    <tbody>
                      {sinStock.map((v) => (
                        <tr key={v.cod_vino}><td>{v.nombre_comercial}</td><td className="num muted">{Number(v.stock_deposito).toLocaleString('es-AR')} en depósito</td></tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </>
            )}
          </div>
        </div>
      </div>
    </>
  )
}
