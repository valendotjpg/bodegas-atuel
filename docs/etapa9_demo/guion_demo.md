# Guion de demo en vivo (10–15 minutos) — sobre la nube

URL: <https://bodegas-atuel.onrender.com>
Base: Neon (branch `production`), API + front en Render.

## 0. Preparación (10 minutos antes de exponer, no en el minuto 0)

Con el plan Free hay dos servicios que se duermen:

- Render: cold start tras ~15 min de inactividad (el primer request tarda
  30–60 s).
- Neon: scale-to-zero tras 5 min (la primera consulta tarda unos segundos).

Protocolo: abrir `/salud` 10 min antes, cargar la página de ventas y dejar la
pestaña del tablero abierta. Si el primer click tarda un poco, es el cold
start, no un error.

## 1. Presentación (1–2 min)

- Mostrar README → URL pública + estructura de etapas.
- Idea central: **las reglas de negocio viven en la base**; la API y el front
  solo muestran lo que devuelve PostgreSQL.
- `/salud` debe devolver `{"user": "bodegas_api", ...}`: la API nunca conecta
  con el rol propietario (mínimo privilegio).

## 2. Venta completa (3 min) — pantalla *Nueva venta*

1. Elegir sala, buscar cliente por documento o por "Cliente..." y **hacer
   click en la fila de resultados** (el botón se habilita cuando sala +
   cliente + renglones están elegidos; si falta algo, la página lo indica).
2. Agregar dos vinos con stock en la sala, cantidades pequeñas.
3. Confirmar: el comprobante aparece calculado por la base (subtotal,
   descuento por tipo de cliente, total).
4. Punto de defensa: el front no calculó nada — el trigger
   `trg_detalle_validar` completó precio, descuento y subtotal en la
   inserción de cada renglón.

## 3. Venta sin stock (2 min) — la regla RN-09 comprobada en producción

Desde la misma pantalla, pedir más de lo que hay (o un vino sin stock en esa
sala). El rechazo viene **de la base, por HTTP**:

```
{"detail":"Stock insuficiente del vino Los horneros (codigo 308) en la sala 6:
hay 0, se piden 5 (RN-09)","sqlstate":"P0001"}  →  HTTP 409
```

- Mensaje legible (nombre + código del vino) porque lo arma el trigger.
- La transacción hace rollback: no queda nada a medias.
- Alternativa por consola (si el front falla):
  `POST /api/comprobantes` con `{"id_sala":6,"id_cliente":1,
  "renglones":[{"cod_vino":308,"cantidad":5}]}`.

## 4. Transferencia (3–4 min) — pantalla *Transferencias*

1. Crear una transferencia para una sala, agregar renglones (vino con stock
   en el depósito), **terminar** y **procesar** — el procedimiento
   `sp_procesar_transferencia` descuenta del depósito y suma a la sala en una
   transacción.
2. Explicar el ciclo de estados `en confección → terminado → procesado`: solo
   terminado impacta stock (RN-11; rechaza si el depósito no tiene stock).
3. Después de procesar, volver a *Nueva venta* y mostrar que el vino recién
   transferido ya se puede vender (asi el stock es consecuencia del flujo del
   enunciado 3.5, nunca se carga a mano).

## 5. Consulta con plan de ejecución (2 min)

- Abrir el plan de S8 (`ventas por sala, último trimestre`) antes/después del
  índice `idx_ventas_trimestre` en `docs/etapa4_rendimiento/`:
  Parallel Seq Scan 7,77 ms → Index Only Scan 1,22 ms (1.246 → 28 buffers).
- Si hay conexión a la base a mano (DBeaver/psql contra Neon), correr un
  `EXPLAIN (ANALYZE, BUFFERS)` en vivo con la consulta de
  `docs/etapa4_rendimiento/s8_consulta.sql`.

## 6. Nube y cierre (2 min)

- Backup/restore verificado: `pg_dump -Fc` → base PG nueva → conteos
  idénticos en las 32 tablas (`docs/etapa8_despliegue/evidencia/05`).
- Controles de integridad del dato en la nube: 0 inconsistencias
  (evidencia 03).
- URL accesible desde cualquier dispositivo (lo probó el grupo).
- Conclusión: qué cambiarían hoy (p. ej. pantalla de ingresos en el front,
  plan pagado para evitar cold starts) — decirlo ustedes, de lo que ya
  conversaron.

## Plan B

- `docker compose up` local con la misma semilla (datos reproducibles) si la
  nube falla.
- Las capturas de `docs/etapa8_despliegue/evidencia/` y
  `docs/etapa2_concurrencia/capturas/` respaldan los puntos 3, 4 y la
  concurrencia si no da para el en vivo.
