use henry_m3;

-- 1) Creamos la tabla que auditará a los usuarios que realizan cambios
DROP TABLE IF EXISTS `fact_venta_auditoria`;
CREATE TABLE IF NOT EXISTS `fact_venta_auditoria` (
	`Fecha`				DATE,
	`Fecha_Entrega`		DATE,
  	`IdCanal` 			INTEGER,
  	`IdCliente` 		INTEGER,
  	`IdEmpleado` 		INTEGER,
  	`IdProducto` 		INTEGER,
    `usuario` 			VARCHAR(20),
    `fechaModificacion` 	DATETIME
);

-- Creamos el trigger que se ejecutara luego de cada inserción
DROP TRIGGER fact_venta_audit;
CREATE TRIGGER fact_venta_audit AFTER INSERT ON fact_venta
FOR EACH ROW
INSERT INTO fact_venta_auditoria
VALUES (NEW.Fecha, NEW.Fecha_Entrega, NEW.IdCanal, NEW.IdCliente, NEW.IdEmpleado, NEW.IdProducto, CURRENT_USER, NOW());

select CURRENT_USER,NOW();

truncate table fact_venta;
truncate table fact_venta_auditoria;

-- 2)
INSERT INTO fact_venta
SELECT IdVenta, Fecha, Fecha_Entrega, IdCanal, IdCliente, IdEmpleado, IdProducto, Precio, Cantidad
FROM venta
WHERE YEAR(Fecha) = 2020;

select count(*) from fact_venta;
select count(*) from fact_venta_auditoria;

-- 3) Creamos la tabla que llevara una cuenta de los registros.
DROP TABLE IF EXISTS `fact_venta_registros`;
CREATE TABLE IF NOT EXISTS `fact_venta_registros` (
  	id_registro INT NOT NULL AUTO_INCREMENT,
	cantidadRegistros INT,
	usuario VARCHAR (20),
	fecha_hora DATETIME,
	PRIMARY KEY (id_registro)
);

-- 4) Creamos el trigger que se ejecutara luego de cada cambio
DROP TRIGGER fact_venta_reg;
CREATE TRIGGER fact_venta_reg AFTER INSERT ON fact_venta
FOR EACH ROW
INSERT INTO fact_venta_registros (cantidadRegistros, usuario, fecha_hora)
VALUES ((SELECT COUNT(*) FROM fact_venta), CURRENT_USER, NOW());

-- 5) Creamos una tabla donde podremos almacenar la cantidad de registros por día
DROP TABLE registros_tablas;
CREATE TABLE registros_tablas (
id_registro INT NOT NULL AUTO_INCREMENT,
tabla VARCHAR(30),
fecha_hora DATETIME,
cantidadRegistros INT,
PRIMARY KEY (id_registro)
);

-- Esta instrucción nos permite cargar la tabla anterior y saber cual es la cantidad de registros por día.
INSERT INTO registros_tablas (tabla, fecha_hora, cantidadRegistros)
SELECT 'venta', Now(), COUNT(*) FROM venta;
INSERT INTO registros_tablas (tabla, fecha_hora, cantidadRegistros)
SELECT 'gasto', Now(), COUNT(*) FROM gasto;
INSERT INTO registros_tablas (tabla, fecha_hora, cantidadRegistros)
SELECT 'compra', Now(), COUNT(*) FROM compra;

SELECT * FROM registros_tablas;
show triggers;

-- 6) Creamos una tabla para auditar cambios
DROP TABLE IF EXISTS `fact_venta_cambios`;
CREATE TABLE IF NOT EXISTS `fact_venta_cambios` (
  	`Fecha` 			DATE,
  	`IdCliente` 		INTEGER,
  	`IdProducto` 		INTEGER,
    `Precio` 			DECIMAL(15,3),
    `Cantidad` 			INTEGER,
    `usuario` 			VARCHAR(20),
    `fechaModificacion` 	DATETIME
);

-- Creamos el trigger que carga nuevos registros
DROP TRIGGER auditoria_cambios;
CREATE TRIGGER auditoria_cambios AFTER UPDATE ON fact_venta
FOR EACH ROW
INSERT INTO fact_venta_cambios (Fecha, IdCliente, IdProducto, Precio, Cantidad, usuario, fechaModificacion)
VALUES (OLD.Fecha,OLD.IdCliente, OLD.IdProducto, OLD.Precio, OLD.Cantidad, CURRENT_USER, NOW());

-- 7)

SELECT * FROM fact_venta_cambios;
select * from fact_venta;
update fact_venta
set Precio = 450
where IdVenta = 10;
