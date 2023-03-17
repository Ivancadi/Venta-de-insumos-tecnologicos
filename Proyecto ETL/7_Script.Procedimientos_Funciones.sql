use henry_m3;

-- 1. Crear un procedimiento que recibe como parametro una fecha
--  y muestre el listado de productos que se vendieron en esa fecha.<br>
DELIMITER $$
CREATE PROCEDURE listaProductos (fechaVenta DATE)
BEGIN
	SELECT DISTINCT p.Producto AS lista_productos
    FROM venta v
    JOIN producto p ON (p.IdProducto = v.IdProducto AND v.Fecha = fechaVenta);
END $$
DELIMITER ;
CALL listaProductos('2019-06-06');

-- 2. Crear una función que calcule el valor nominal de un margen bruto determinado
-- por el usuario a partir del precio de lista de los productos.
DELIMITER $$
CREATE FUNCTION margenBruto (precio DECIMAL(15,2), margen DECIMAL(8,2)) RETURNS DECIMAL(15,2)
BEGIN
	DECLARE margenBruto DECIMAL(15,2);
    SET margenBruto = precio * margen;
    RETURN margenBruto;
END $$
DELIMITER ;
SELECT margenBruto(100, 1.2);

-- 3. Obtener un listado de productos de IMPRESION y utilizarlo para cálcular
-- el valor nominal de un margen bruto del 20% de cada uno de los productos.
SELECT p.IdProducto, p.Producto, p.Precio, margenBruto(p.Precio, 1.2) as precio_con_margen
FROM producto p
JOIN tipo_producto tp ON(p.IdTipoProducto = tp.IdTipoProducto) -- AND tp.TipoProducto = 'Impresión');
WHERE tp.TipoProducto = 'Impresión';

-- 4. Crear un procedimiento que permita listar los productos
-- vendidos desde fact_venta a partir de un "Tipo" que determine el usuario.
DROP PROCEDURE listaProductosCategoria;
DELIMITER $$
CREATE PROCEDURE listaProductosCategoria (categoria VARCHAR(40) CHARSET utf8mb4 COLLATE utf8mb4_spanish_ci)
BEGIN
	SELECT fv.*, dp.Producto
    FROM fact_venta fv
    JOIN dim_producto dp ON(fv.IdProducto = dp.IdProducto)
    JOIN tipo_producto tp ON(dp.IdTipoProducto = tp.IdTipoProducto
		AND tp.TipoProducto = categoria);
END $$
DELIMITER ;
CALL listaProductosCategoria('Impresión');

-- 5. Crear un procedimiento que permita realizar la insercción de datos en la tabla fact_venta.
DELIMITER $$
CREATE PROCEDURE cargar_fact_venta()
BEGIN
	TRUNCATE TABLE fact_venta;
    INSERT INTO fact_venta
    SELECT IdVenta, Fecha, Fecha_Entrega, IdCanal, IdCliente, IdEmpleado, IdProducto, Precio, Cantidad
    FROM venta
    WHERE Outlier = 1
    LIMIT 10;
END $$
DELIMITER ;

CALL cargar_fact_venta;
-- 6. Crear un procedimiento almacenado que reciba un grupo etario y devuelta el total de ventas para ese grupo.
DELIMITER $$
CREATE PROCEDURE ventaGrupoEtario(rango_etario VARCHAR(40) CHARSET utf8mb4 COLLATE utf8mb4_spanish_ci)
BEGIN
	SELECT c.Rango_Etario, SUM(v.Precio * v.Cantidad) as total_venta
	FROM venta v
	JOIN cliente c ON(v.IdCliente = c.IdCliente
					 AND c.Rango_Etario LIKE concat('%', rango_etario, '%'))
	GROUP BY c.Rango_Etario;
END $$
DELIMITER ;

SELECT DISTINCT Rango_Etario
FROM cliente
WHERE Rango_Etario LIKE '%51 a 60%';

-- CALL ventaGrupoEtario('%51 a 60%');
CALL ventaGrupoEtario(@grupo_etario);

-- 7. Crear una variable que se pase como valor para realizar una filtro
-- sobre Rango_etario en una consulta génerica a dim_cliente.
SET @grupo_etario = '4_De 51 a 60 años'COLLATE utf8mb4_spanish_ci;
SELECT *
FROM dim_cliente
WHERE Rango_Etario = @grupo_etario;

#8
/*Función y Procedimiento provistos*/
-- SET GLOBAL log_bin_trust_function_creators = 1;

DROP FUNCTION IF EXISTS `UC_Words`;
DELIMITER $$
CREATE DEFINER=`root`@`localhost` FUNCTION `UC_Words`( str VARCHAR(255) ) RETURNS varchar(255) CHARSET utf8mb4
BEGIN  
  DECLARE c CHAR(1);  
  DECLARE s VARCHAR(255);  
  DECLARE i INT DEFAULT 1;  
  DECLARE bool INT DEFAULT 1;  
  DECLARE punct CHAR(17) DEFAULT ' ()[]{},.-_!@;:?/';  
  SET s = LCASE( str );  
  WHILE i < LENGTH( str ) DO  
     BEGIN  
       SET c = SUBSTRING( s, i, 1 );  
       IF LOCATE( c, punct ) > 0 THEN  
        SET bool = 1;  
      ELSEIF bool=1 THEN  
        BEGIN  
          IF c >= 'a' AND c <= 'z' THEN  
             BEGIN  
               SET s = CONCAT(LEFT(s,i-1),UCASE(c),SUBSTRING(s,i+1));  
               SET bool = 0;  
             END;  
           ELSEIF c >= '0' AND c <= '9' THEN  
            SET bool = 0;  
          END IF;  
        END;  
      END IF;  
      SET i = i+1;  
    END;  
  END WHILE;  
  RETURN s;  
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS `Llenar_dimension_calendario`;
DELIMITER $$
CREATE DEFINER=`root`@`localhost` PROCEDURE `Llenar_dimension_calendario`(IN `startdate` DATE, IN `stopdate` DATE)
BEGIN
    DECLARE currentdate DATE;
    SET currentdate = startdate;
    WHILE currentdate < stopdate DO
        INSERT INTO calendario VALUES (
                        YEAR(currentdate)*10000+MONTH(currentdate)*100 + DAY(currentdate),
                        currentdate,
                        YEAR(currentdate),
                        MONTH(currentdate),
                        DAY(currentdate),
                        QUARTER(currentdate),
                        WEEKOFYEAR(currentdate),
                        DATE_FORMAT(currentdate,'%W'),
                        DATE_FORMAT(currentdate,'%M'));
        SET currentdate = ADDDATE(currentdate,INTERVAL 1 DAY);
    END WHILE;
END$$
DELIMITER ;

/*Se genera la dimension calendario*/
DROP TABLE IF EXISTS `calendario`;
CREATE TABLE calendario (
        idFecha                     INTEGER PRIMARY KEY,  -- year*10000+month*100+day
        fecha                 	DATE NOT NULL,
        anio                    INTEGER NOT NULL,
        mes                   	INTEGER NOT NULL, -- 1 to 12
        dia                     INTEGER NOT NULL, -- 1 to 31
        trimestre               INTEGER NOT NULL, -- 1 to 4
        semana                  INTEGER NOT NULL, -- 1 to 52/53
        dia_nombre              VARCHAR(9) NOT NULL, -- 'Monday', 'Tuesday'...
        mes_nombre              VARCHAR(9) NOT NULL -- 'January', 'February'...
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_spanish_ci;

ALTER TABLE `calendario` ADD UNIQUE(`fecha`);

/*LOAD DATA INFILE 'C:\\ProgramData\\MySQL\\MySQL Server 8.0\\Uploads\\Calendario.csv' 
INTO TABLE calendario
FIELDS TERMINATED BY ',' ENCLOSED BY '' ESCAPED BY '' 
LINES TERMINATED BY '\n' IGNORE 1 LINES;*/

-- 8)
/*Normalizacion a Letra Capital*/
UPDATE cliente SET  Domicilio = UC_Words(TRIM(Domicilio)),
                    Nombre_y_Apellido = UC_Words(TRIM(Nombre_y_Apellido));
					
UPDATE sucursal SET Domicilio = UC_Words(TRIM(Domicilio)),
                    Sucursal = UC_Words(TRIM(Sucursal));
					
UPDATE proveedor SET Nombre = UC_Words(TRIM(Nombre)),
                    Domicilio = UC_Words(TRIM(Domicilio));

UPDATE producto SET Producto = UC_Words(TRIM(Producto));

UPDATE tipo_producto SET TipoProducto = UC_Words(TRIM(TipoProducto));
					
UPDATE empleado SET Nombre = UC_Words(TRIM(Nombre)),
                    Apellido = UC_Words(TRIM(Apellido));

UPDATE sector SET Sector = UC_Words(TRIM(Sector));

UPDATE cargo SET Cargo = UC_Words(TRIM(Cargo));
                    
UPDATE localidad SET Localidad = UC_Words(TRIM(Localidad));

UPDATE provincia SET Provincia = UC_Words(TRIM(Provincia));

UPDATE dim_cliente SET 	Domicilio = UC_Words(TRIM(Domicilio)),
                    Nombre_y_Apellido = UC_Words(TRIM(Nombre_y_Apellido));

UPDATE dim_producto SET Producto = UC_Words(TRIM(Producto));

-- 9)
/*TRUNCATE TABLE calendario;*/
CALL Llenar_dimension_calendario('2015-01-01','2021-01-01');
SELECT * FROM calendario;

ALTER TABLE venta ADD CONSTRAINT `venta_fk_fecha` FOREIGN KEY (fecha) REFERENCES calendario (fecha) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE compra ADD CONSTRAINT `compra_fk_fecha` FOREIGN KEY (Fecha) REFERENCES calendario (fecha) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE gasto ADD CONSTRAINT `gasto_fk_fecha` FOREIGN KEY (Fecha) REFERENCES calendario (fecha) ON DELETE RESTRICT ON UPDATE RESTRICT;