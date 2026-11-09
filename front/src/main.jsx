import React from 'react'
import ReactDOM from 'react-dom/client'
import { BrowserRouter, NavLink, Route, Routes } from 'react-router-dom'
import './styles.css'
import Catalogo from './pages/Catalogo.jsx'
import VinoForm from './pages/VinoForm.jsx'
import Venta from './pages/Venta.jsx'
import Transferencias from './pages/Transferencias.jsx'
import Tablero from './pages/Tablero.jsx'

function App() {
  return (
    <>
      <header className="barra">
        <div className="marca"><span className="marca-punto" />Bodegas del Atuel</div>
        <nav className="nav">
          <NavLink to="/" end>Catálogo</NavLink>
          <NavLink to="/vinos/nuevo">Nuevo vino</NavLink>
          <NavLink to="/venta">Nueva venta</NavLink>
          <NavLink to="/transferencias">Transferencias</NavLink>
          <NavLink to="/tablero">Tablero</NavLink>
        </nav>
      </header>
      <main className="contenido">
        <Routes>
          <Route path="/" element={<Catalogo />} />
          <Route path="/vinos/nuevo" element={<VinoForm />} />
          <Route path="/vinos/:cod/editar" element={<VinoForm />} />
          <Route path="/venta" element={<Venta />} />
          <Route path="/transferencias" element={<Transferencias />} />
          <Route path="/tablero" element={<Tablero />} />
        </Routes>
      </main>
    </>
  )
}

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <BrowserRouter>
      <App />
    </BrowserRouter>
  </React.StrictMode>,
)
