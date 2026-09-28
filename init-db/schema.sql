CREATE TABLE IF NOT EXISTS ventas_limpias (
    id SERIAL PRIMARY KEY,
    producto VARCHAR(100) NOT NULL,
    cantidad INTEGER NOT NULL CHECK (cantidad > 0),
    precio_unitario DECIMAL(10,2) NOT NULL,
    total DECIMAL(10,2) NOT NULL,
    fecha DATE NOT NULL,
    cliente VARCHAR(100),
    ciudad VARCHAR(50) NOT NULL,
    cargado_en TIMESTAMP DEFAULT NOW()
)