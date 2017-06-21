SET DATEFIRST 7
SET ANSI_NULLS OFF
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET LOCK_TIMEOUT - 1
SET QUOTED_IDENTIFIER OFF
GO

IF EXISTS (
  SELECT *
  FROM sysobjects
  WHERE id = object_id(N'[dbo].[fnGenerarFacturarXMLBatch]')
   AND type in ( N'FN', N'IF', N'TF', N'FS', N'FT' )
  )
   DROP FUNCTION [dbo].[fnGenerarFacturarXMLBatch]
GO
CREATE FUNCTION fnGenerarFacturarXMLBatch (@ID int)         
RETURNS xml            
AS            
BEGIN            
  DECLARE @xmlFactura xml,            
          @xmlHDescuentos xml,            
          @xmlHImpuestos xml,            
          @xmlTotales xml,            
          @xmlDetalles xml,            
          @xmlAsignacionSolicitada xml,            
          @xmlEncabezado xml,            
          @xmlVendedor xml,            
          @xmlComprador xml,            
          @HPorcentajeDescuento money,            
          @HPorcentajeDescuentoGlobal money,            
          @HValorDescuento money,            
          @HValorFactura money,            
          @HValorFacturaSinDescuento money,            
          @HValorFacturaSinIva money,            
          @HValorIva money,            
          @DPorcentajeIva money,            
          @TipoActivo varchar(50),            
          @Estatus varchar(20),            
          @FechaCancelacion date,            
          @TipoCambio money,            
          @Vin varchar(20),            
          @Linea1 varchar(250),            
    @Linea2 varchar(250),            
    @Linea3 varchar(250),            
    @Linea4 varchar(250),            
    @Linea5 varchar(250),            
    @Linea6 varchar(250),            
    @Linea7 varchar(250),            
    @Linea8 varchar(250),            
    @Linea9 varchar(250)            
            
            
            
            
            
  SELECT            
    @TipoActivo =            
                 CASE            
                   WHEN V.Mov LIKE 'Factura%' THEN 'CFACE1'            
                   ELSE 'CNCE5'            
                 END,            
    @Estatus =            
              CASE            
                WHEN V.Estatus = 'CONCLUIDO' THEN 'ORIGINAL'            
                WHEN V.Estatus = 'CANCELADO' THEN 'ANULADO'            
              END,            
    @FechaCancelacion = CONVERT(varchar, FechaCancelacion, 126),            
    @Vin = 'NORMAL'            
  FROM VENTA V            
  WHERE V.ID = @ID            
            
  SELECT            
    @Vin = Tipo            
  FROM ventad vd            
  JOIN art            
    ON vd.Articulo = art.Articulo            
    AND tipo = 'VIN'            
    AND vd.id = @id            
 --rogelio perez 09/03/2017 detalle factura electronica           
   SELECT @Linea1 = concat(a.articulo,' - ',a.descripcion1) ,            
    @Linea2 = concat(A.TIPOVEHICULO ,' Marca ', A.Fabricante, ' Modelo ',Vin.modelo),            
    @Linea3 = concat('Linea ', a.Descripcion1,' C.C. ',Vin.Codigollanta3,' Cilindros ',Vin.Cilindros) ,            
    @Linea4 = concat('Ejes ',Vin.CodigoLlanta2,' Asientos ',Vin.Pasajeros,',',.vin.Placas) ,            
    @Linea5 = concat('Con SERIE, CHASIS Y VIN No.',Vin.Vin) ,            
    @Linea6 = concat ('Combustible ',Vin.Combustible,' Motor ',Vin.Motor) ,            
    @Linea7 = concat('Color ',Vin.ColorExteriorDescripcion) ,            
    @Linea8 = concat('Aduana ',Vin.Aduana) ,            
    @Linea9 = concat('Poliza ',Vin.Pedimento)            
    FROM Venta          
    LEFT OUTER JOIN Cte          ON Venta.Cliente = Cte.Cliente          
    LEFT OUTER JOIN Cte Fac      ON Venta.EndosarA = Fac.Cliente          
    JOIN VentaD       ON Venta.ID = VentaD.ID          
    JOIN VentaTCalc   ON Venta.ID = VentaTCalc.ID          
    LEFT OUTER JOIN SerieLoteMov ON (Serielotemov.Empresa = Venta.Empresa AND Serielotemov.Modulo='VTAS' and Serielotemov.ID=Venta.ID and serielotemov.renglonid = ventad.renglonid and serielotemov.articulo = ventad.articulo)          
    LEFT OUTER JOIN VIN          ON SerieLoteMov.SerieLote = VIN.VIN          
    JOIN Art        A  ON VentaD.Articulo = A.Articulo          
    JOIN Agente ON Venta.Agente = Agente.Agente          
    where ventad.id=@ID            
            
  SELECT            
    @xmlTotales = (SELECT (SELECT            
                            CASE            
                  WHEN @Vin = 'VIN' THEN CAST(TotalImporte AS money)            
                              ELSE CAST(PrecioSinIva AS money)            
             END)            
                          AS SubTotalSinDR,            
                          (SELECT            
                            CASE            
       WHEN @Vin = 'VIN' THEN 0            
                              ELSE CAST(ValorDescuento AS money)            
                            END AS SumaDeDescuentos,            
   CASE            
                              WHEN @Vin = 'VIN' THEN (SELECT            
                                  'DESCUENTO' AS Operacion,            
                                  'ALLOWANCE_GLOBAL' AS Servicio,            
                                  CAST(TotalImporte AS money) AS Base,            
                                  0 AS Tasa,            
                                  0 AS Monto            
                                FOR xml PATH ('DescuentoORecargo'), TYPE)            
                              ELSE (SELECT            
                                  'DESCUENTO' AS Operacion,            
                                  'ALLOWANCE_GLOBAL' AS Servicio,            
                                  CAST(PrecioSinIva AS money) AS Base,            
                                  CAST(DescuentoPorcentaje AS money) AS Tasa,            
                                  CAST(ValorDescuento AS money) AS Monto            
                                FOR xml PATH ('DescuentoORecargo'), TYPE)            
                            END            
                          FOR xml PATH ('DescuentosYRecargos'), TYPE),            
                          CAST(TotalImporte AS money) AS SubTotalConDR,            
                          (SELECT            
                            CAST(TotalImpuestos AS money) AS TotalDeImpuestos,            
                            CAST(TotalImporte AS money) AS IngresosNetosGravados,            
                            CAST(TotalImpuestos AS money) AS TotalDeIVA,            
                            (SELECT            
                              'IVA' AS Tipo,            
                              CAST(TotalImporte AS money) AS Base,            
                              CAST(Iva AS money) AS Tasa,            
                              CAST(TotalImpuestos AS money) AS Monto            
                            FOR xml PATH ('Impuesto'), TYPE)            
                          FOR xml PATH ('Impuestos'), TYPE),            
                          CAST(TotalFacturaConIva AS money) AS Total,            
                          UPPER(dbo.fnNumeroEnEspanol(((TotalFacturaConIva)), '')) AS TotalLetras            
    FROM (SELECT            
      (1 - ROUND((TotalFacturaConIva / PrecioTotal), 2)) * 100 AS DescuentoTotal,            
      CASE            
        WHEN PrecioSinIva - TotalImporte <= 0 THEN 0            
        ELSE (PrecioSinIva - TotalImporte)            
      END AS ValorDescuento,            
      ROUND((TotalImpuestos / TotalImporte), 2) * 100 AS Iva,            
      CASE            
        WHEN PrecioSinIva - TotalImporte <= 0 THEN 0            
        ELSE ROUND(((PrecioSinIva - TotalImporte) * 100 / PrecioSinIva), 2)            
      END AS DescuentoPorcentaje,            
      *            
    FROM (SELECT            
      (v.PrecioTotal * TipoCambio) AS PrecioTotal,            
      ROUND(PrecioTotal * (1 - IVAFiscal) * TipoCambio, 2) AS PrecioSinIva,            
      ISNULL(DescuentoGlobal, 0.0) DescuentoGlobal,            
      v.TipoCambio,            
      ROUND((v.Importe - (v.Importe * (ISNULL(DescuentoGlobal, 0.0) / 100.0))) * TipoCambio, 2) AS TotalImporte,            
      ROUND(v.Impuestos * TipoCambio, 2) AS TotalImpuestos,            
      ROUND((v.Importe - (v.Importe * (ISNULL(DescuentoGlobal, 0.0) / 100.0)) + v.Impuestos) * TipoCambio, 2) AS TotalFacturaConIva            
    FROM Venta v   
    WHERE v.id = @id) AS Factura) AS FacturaTotales            
    FOR xml PATH ('Totales')            
    , TYPE)            
            
            
            
  SELECT            
    @xmlDetalles = (SELECT (SELECT       
     --[FIX] Rogelio Perez - Correcion Descripcion Detalle Factura XML 06/06/2017 Ticket 18827      
        SUBSTRING(dbo.fnCadenaNormaliza(concat(case when articulo is not null then concat(articulo,'-') else '' end,DescripcionExtra)), 0, 70) AS Descripcion,            
        '00000000000000' AS CodigoEAN,            
        UnidadDeMedida,            
        Cantidad,            
        (SELECT            
          CASE            
            WHEN @Vin = 'VIN' THEN CAST((PrecioTotalSinIvaConDescuentoGlobal / Cantidad) AS money)            
            ELSE CAST(PrecioSinIva AS money)            
          END AS Precio,            
          CASE            
            WHEN @Vin = 'VIN' THEN CAST(PrecioTotalSinIvaConDescuentoGlobal AS money)            
            ELSE CAST(PrecioTotalSinIva AS money)            
          END AS Monto            
        FOR xml PATH ('ValorSinDR'), TYPE),         
        (SELECT            
          CASE            
            WHEN @Vin = 'VIN' THEN 0            
            ELSE CAST(ValorDeDecuento AS money)            
          END AS SumaDeDescuentos,            
          (SELECT            
            'DESCUENTO' AS Operacion,            
            'ALLOWANCE_GLOBAL' AS Servicio,            
            CASE            
              WHEN @Vin = 'VIN' THEN CAST(PrecioTotalSinIvaConDescuentoGlobal AS money)            
              ELSE CAST(PrecioTotalSinIva AS money)            
            END AS Base,            
            CASE            
              WHEN @Vin = 'VIN' THEN 0            
              ELSE CAST(PorcentajeDescuento AS money)            
            END AS Tasa, /*****************************************************************************************************************/            
            CASE            
              WHEN @Vin = 'VIN' THEN 0            
              ELSE CAST(ValorDeDecuento AS money)            
            END AS Monto            
          FOR xml PATH ('DescuentoORecargo'), TYPE)            
        FOR xml PATH ('DescuentosYRecargos'), TYPE),            
        (SELECT            
          CAST(PrecioSinIvaConDescuentoGlobal AS money) AS Precio,            
          CAST(PrecioTotalSinIvaConDescuentoGlobal AS money) AS Monto            
        FOR xml PATH ('ValorConDR'), TYPE),            
        (SELECT            
          CAST(ValorTotalIvaConDescuentoGlobal AS money) AS TotalDeImpuestos,            
          CAST(PrecioTotalSinIvaConDescuentoGlobal AS money) AS IngresosNetosGravados,            
          CAST(ValorTotalIvaConDescuentoGlobal AS money) AS TotalDeIVA,            
          (SELECT            
            'IVA' AS Tipo,            
            CAST(PrecioTotalSinIvaConDescuentoGlobal AS money) Base,            
            CAST(Impuesto1 AS money) Tasa,            
            CAST(ValorTotalIvaConDescuentoGlobal AS money) AS Monto            
          FOR xml PATH ('Impuesto'), TYPE)            
        FOR xml PATH ('Impuestos'), TYPE),            
        Categoria,  --rogelio perez 09/03/2017 detalle factura electronica          
  case when @vin='VIN' THEN (select @Linea1 as Texto,null,               
   @Linea2             
   AS Texto,NULL,            
   @Linea3             
   AS Texto,NULL,            
   @Linea4             
   AS Texto,NULL,            
   @Linea5             
   AS Texto,NULL,              
   @Linea6             
   AS Texto,NULL,               
   @Linea7             
   AS Texto,NULL,               
   @Linea8             
   AS Texto,NULL            
        FOR xml PATH ('TextosDePosicion'), TYPE) END           
      FROM (SELECT            
        *,            
        ROUND(VentaDetalle.PrecioTotalSinIvaConDescuentoGlobal / VentaDetalle.Cantidad, 2) AS PrecioSinIvaConDescuentoGlobal,   
        ROUND(100 - ROUND(((VentaDetalle.PrecioTotalSinIvaConDescuentoGlobal / VentaDetalle.PrecioTotalSinIva) * 100), 4), 2) AS PorcentajeDescuento,            
        PrecioTotalSinIva - PrecioTotalSinIvaConDescuentoGlobal AS ValorDeDecuento            
      FROM (SELECT            
        *,            
        ROUND(venta.PrecioSinIvaConDescuento - (venta.PrecioSinIvaConDescuento * DescuentoGlobal / 100.0), 2) AS PrecioTotalSinIvaConDescuentoGlobal,            
        ROUND(venta.ValorIvaConDescuento - (venta.ValorIvaConDescuento * DescuentoGlobal / 100.0), 2) AS ValorTotalIvaConDescuentoGlobal            
      FROM (SELECT            
        ROUND(precio / (1 + (vd.Impuesto1 / 100.0)) * TipoCambio, 2) AS PrecioSinIva --Precio de Linea Sin Iva             
        ,            
        ROUND(precio * vd.Cantidad / (1 + (vd.Impuesto1 / 100.0)) * TipoCambio, 2) AS PrecioTotalSinIva --Precio Total de Linea Sin Iva             
        ,            
        ROUND(((ROUND((precio * vd.Cantidad) / (1 + (vd.Impuesto1 / 100.0)), 2)) - (ROUND(((precio * vd.Cantidad) / (1 + (vd.Impuesto1 / 100.0))) - (precio * vd.Cantidad) / (1 + (vd.Impuesto1 / 100.0)) * (DescuentoLinea / 100.0), 2))) * TipoCambio, 2) AS
   
    
     
         
          
DescuentoSinIva,            
        ((((precio * vd.Cantidad) / (1 + (vd.Impuesto1 / 100.0))) - (precio * vd.Cantidad) / (1 + (vd.Impuesto1 / 100.0)) * (ISNULL(DescuentoLinea, 0.0) / 100.0))) * TipoCambio AS PrecioSinIvaConDescuento--Precio de Linea Sin Iva y Con Descuento          
  
        ,            
        ((((precio * vd.Cantidad) / (1 + (vd.Impuesto1 / 100.0))) - (precio * vd.Cantidad) / (1 + (vd.Impuesto1 / 100.0)) * (ISNULL(DescuentoLinea, 0.0) / 100.0)) * (vd.Impuesto1 / 100.0)) * TipoCambio AS ValorIvaConDescuento--Iva Con Descuento           
 
        ,            
        vd.DescuentoLinea,            
        ISNULL(DescuentoGlobal, 0.0) DescuentoGlobal,            
        vd.Impuesto1,            
        CAST(Cantidad AS money) AS Cantidad,            
        DescripcionExtra,            
        'PZA' AS UnidadDeMedida,            
        CASE            
          WHEN Art.TIPO IN ('Normal', 'VIN') THEN 'BIEN'            
          ELSE 'SERVICIO'            
        END AS Categoria,            
--  (select @Linea1 ) as textoI,             
        v.TipoCambio,            
        vd.Articulo,            
        ROUND((v.Importe - (v.Importe * (ISNULL(DescuentoGlobal, 0.0) / 100.0))) * TipoCambio, 2) AS TotalImporte,            
        ROUND(v.Impuestos * TipoCambio, 2) AS TotalImpuestos,            
        ROUND((v.Importe - (v.Importe * (ISNULL(DescuentoGlobal, 0.0) / 100.0)) + v.Impuestos) * TipoCambio, 2) AS TotalFacturaConIva,            
        Art.tipo AS TipoArticulo            
      FROM Venta v            
      JOIN Ventad vd            
        ON vd.id = v.id            
      JOIN art            
        ON art.articulo = vd.articulo            
      WHERE v.id = @ID) AS Venta) AS VentaDetalle) AS Factura            
            
               
      FOR xml PATH ('Detalle'), TYPE)            
    FOR xml PATH ('Detalles'), TYPE)            
            
  -- select dbo.fnSerieFacturaGuatemala('C-494279')              
  SELECT            
    @xmlAsignacionSolicitada = (SELECT            
      CASE            
        WHEN dbo.fnSerieFacturaGuatemala(MovID) = '' THEN '.'            
        WHEN dbo.fnSerieFacturaGuatemala(MovID) = '-' THEN '.'            
        WHEN dbo.fnSerieFacturaGuatemala(MovID) IS NULL THEN '.'    
        WHEN dbo.fnSerieFacturaGuatemala(MovID) = '.A' THEN REPLACE(REPLACE (dbo.fnSerieFacturaGuatemala(MovID),'.',''),'-','') --rp 19/06/17 Remover "." Serie .A        
        ELSE dbo.fnSerieFacturaGuatemala(MovID)            
      END AS Serie,            
      --isnull(nullif(dbo.fnSerieFacturaGuatemala(v.MovID),''),'SIN SERIE') AS Serie,               
      REPLACE(REPLACE(REPLACE(MovID, ISNULL(dbo.fnSerieFacturaGuatemala(MovID), ''), ''), '-', ''), ' ', '') AS NumeroDocumento,            
      CONVERT(varchar, FechaEmision, 126) AS FechaEmision,            
      Resolucion AS NumeroAutorizacion,            
      CONVERT(varchar, FechaResolucion, 126) AS FechaResolucion,            
      RangoInicialAutorizado AS RangoInicialAutorizado,            
      RangoFinalAutorizado AS RangoFinalAutorizado            
    FROM VENTA V            
    JOIN FACTURAELECTRONICACF CF            
      ON CF.Empresa = V.Empresa            
      AND V.Sucursal = CF.SUCURSAL            
      AND CF.Serie = case  WHEN dbo.fnSerieFacturaGuatemala(MovID) = '.A' then REPLACE(REPLACE (dbo.fnSerieFacturaGuatemala(MovID),'.',''),'-','') else ISNULL(NULLIF(dbo.fnSerieFacturaGuatemala(v.MovID), ''), '-') end --rp 19/06/17 Remover "." Serie .A             
    WHERE V.ID = @ID            
    FOR xml PATH ('AsignacionSolicitada')            
    , TYPE)            
            
  SELECT            
    @xmlEncabezado = (SELECT            
      @TipoActivo AS TipoActivo,            
      @Estatus AS RedefinirEstadoDeCopia,            
      @FechaCancelacion AS FechaCancelacion,            
      'GTQ' AS CodigoDeMoneda,            
      '1.0000' AS TipoDeCambio,            
      'PAGO_TRIMESTRAL' AS InformacionDeRegimenIsr            
    FOR xml PATH ('Encabezado')            
    , TYPE)            
            
  SELECT            
    @xmlVendedor = (SELECT            
      REPLACE(STR(REPLACE(ISNULL(NULLIF(RFC, ''), 'CF'), '-', ''), 12), ' ', '0') AS Nit,            
      --'000000123456' as Nit,               
      S.Nombre AS NombreComercial,            
      'es' AS Idioma,            
      (SELECT            
        CF.NomEstablecimiento AS NombreDeEstablecimiento,            
        CF.CodigoDeEstablecimiento AS CodigoDeEstablecimiento,            
        --'209'       AS CodigoDeEstablecimiento,               
        CF.DispositivoElectronico AS DispositivoElectronico,            
        dbo.fnCadenaNormaliza(ISNULL(NULLIF(s.Direccion, ''), '---')) AS Direccion1,            
        '---' AS Direccion2,            
        ISNULL(NULLIF(s.Delegacion, ''), 'GUATEMALA') AS Municipio,            
        ISNULL(NULLIF(s.Estado, ''), 'GUATEMALA') AS Departamento,            
        'GT' AS CodigoDePais,            
        ISNULL(NULLIF(CodigoPostal, ''), '---') AS CodigoPostal            
      FOR xml PATH ('DireccionDeEmisionDeDocumento'), TYPE)            
    FROM venta v            
    JOIN Sucursal s            
      ON v.Sucursal = s.Sucursal            
    JOIN FACTURAELECTRONICACF CF            
      ON CF.Empresa = V.Empresa            
      AND V.Sucursal = CF.SUCURSAL            
      AND CF.Serie = case  WHEN dbo.fnSerieFacturaGuatemala(MovID) = '.A' then REPLACE(REPLACE (dbo.fnSerieFacturaGuatemala(MovID),'.',''),'-','') else ISNULL(NULLIF(dbo.fnSerieFacturaGuatemala(v.MovID), ''), '-') end --rp 19/06/17 Remover "." Serie .A            
    WHERE V.ID = @ID            
    FOR xml PATH ('Vendedor')            
    , TYPE)            
            
  SELECT            
    @xmlComprador = (SELECT            
      CASE            
        WHEN V.Concepto = 'Exportación' THEN 'EXPORT'            
        ELSE dbo.fnNitFormat(COALESCE(F.RFC, C.RFC))            
      END AS Nit,            
      --replace(isnull(nullif(coalesce(F.RFC,C.RFC),''),'C/F'),'-','') as Nit,                
      dbo.fnCadenaNormaliza(COALESCE(F.Nombre, C.Nombre)) AS NombreComercial,            
      'es' AS Idioma,            
      (SELECT            
        dbo.fnCadenaNormaliza(CASE            
          WHEN LEN(ISNULL(NULLIF(COALESCE(F.Direccion, C.Direccion), ''), 'CIUDAD')) <= 80 THEN ISNULL(NULLIF(COALESCE(F.Direccion, C.Direccion), ''), 'CIUDAD')            
          ELSE 'CIUDAD'            
        END) AS Direccion1,            
        '----' AS Direccion2,            
        ISNULL(NULLIF(COALESCE(F.Delegacion, C.Delegacion), ''), '---') AS Municipio,            
        ISNULL(NULLIF(COALESCE(F.Estado, C.Estado), ''), '---') AS Departamento,            
        'GT' AS CodigoDePais,            
        ISNULL(NULLIF(COALESCE(F.CodigoPostal, C.CodigoPostal), ''), '---') AS CodigoPostal,            
        '---' AS Telefono            
      FOR xml PATH ('DireccionComercial'), TYPE)            
    FROM venta v            
    LEFT OUTER JOIN Cte C            
      ON V.Cliente = C.Cliente            
    LEFT OUTER JOIN Cte F            
      ON V.EndosarA = F.Cliente            
    WHERE V.ID = @ID            
    FOR xml PATH ('Comprador')        
    , TYPE)            
            
            
  SELECT            
    @xmlFactura = (SELECT            
      '2' AS Version,            
      @xmlAsignacionSolicitada,            
      @xmlEncabezado,            
      @xmlVendedor,            
      @xmlComprador,            
      @xmlDetalles,            
 @xmlTotales            
    FOR xml PATH ('')            
    , TYPE)            
  RETURN @xmlFactura            
END 