/****** Object:  StoredProcedure [dbo].[spAltaArticuloMasterPolaris]    Script Date: 3/05/2017 14:09:18 ******/
DROP PROCEDURE [dbo].[spAltaArticuloMasterPolaris]
GO

/****** Object:  StoredProcedure [dbo].[spAltaArticuloMasterPolaris]    Script Date: 3/05/2017 14:09:18 ******/
SET DATEFIRST 7
SET ANSI_NULLS OFF
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET LOCK_TIMEOUT -1
SET QUOTED_IDENTIFIER OFF
 
GO  
/*********************** ROCEDIMIENTO PARA ALTA RAPIDA DE ARTICULOS POLARIS *******************************************************/  
/****** Object:  StoredProcedure [dbo].[spAltaArticuloMasterPolaris]    Script Date: 20/02/2017 16:30:28 ******/  
  
  
CREATE PROCEDURE [dbo].[spAltaArticuloMasterPolaris]         
        @Empresa           char   ( 5),          
        @EstacionTrabajo   int        ,          
        @Usuario           varchar(10),          
        @Sucursal          int                  
AS          
BEGIN          
  DECLARE          
        @TipoCosteo        varchar(20),          
        @Proveedor         varchar(10),          
        @IDCosto           int        ,          
        @IDPrecio          int        ,          
        @TCEuros           float      ,          
        @TCDolares         float                
            
  CREATE TABLE #PCDTemp          
      (           
        Renglon        int   identity(2048,2048),          
        Articulo       varchar(20),          
        Anterior       float       NULL,          
        Nuevo          money      ,          
        Unidad         varchar(50) NULL          
       )          
          
          
  SELECT @TipoCosteo = FordTipoCosteoRefacciones,           
         @Proveedor  = FordCliente           
    FROM EmpresaGral          
   WHERE Empresa = @Empresa          
            
  SELECT @TCEuros = ISNULL(TipoCambio,0)          
    FROM Mon          
   WHERE Moneda = 'Euros'          
               
  SELECT @TCDolares = ISNULL(TipoCambio,0)          
    FROM Mon          
   WHERE Moneda = 'Dolar'          
             
  INSERT Art           
        ( Articulo, Descripcion1, Categoria, Familia, Fabricante, ClaveFabricante, Impuesto1, Unidad, UnidadCompra,           
          UnidadTraspaso, UnidadCantidad,TipoCosteo, Peso, Tipo, TipoOpcion, MonedaCosto, MonedaPrecio, FactorAlterno,           
          Estatus, Alta, UltimoCambio, Usuario, EstatusPrecio, WMostrar, SeCompra, SeVende, RevisionUsuario, RutaDistribucion,           
          EstatusCosto, Proveedor, FactorCompra, GrupoDeUtilidad, CodigoAlterno, Presentacion, TipoImpuesto1)          
  SELECT A.Articulo, A.Descripcion, 'Repuestos', 'Repuestos', 'Polaris', A.Articulo, 12, 'pza', 'pza',          
         'pza', 1, @TipoCosteo, null, 'Normal', 'No', 'Quetzales', 'Dolar', 1,           
         'ALTA', GETDATE(), GETDATE(), @Usuario, 'NUEVO', 1, 1, 1, @Usuario, 1,           
         'SINCAMBIO', @Proveedor,1, 'DF', A.Articulo, 'GENERICO', 'IVA'      
    FROM MasterRepuestosPolaris A          
    JOIN AltaArticuloPolaris    B ON A.Articulo = B.Articulo          
   WHERE B.Estacion = @EstacionTrabajo          
      
              
-- ACTUALIZAR PRECIO DHL            
  TRUNCATE TABLE #PCDTemp          
            
  INSERT #PCDTemp           
        ( Articulo , Anterior, Nuevo)          
  SELECT A.Articulo , null,
    Round(Precio * Distributornet,2)      
    FROM MasterRepuestosPolaris            A          
    JOIN Art          B ON A.Articulo        = B.Articulo          
    JOIN AltaArticuloPolaris               C ON A.Articulo        = C.Articulo                
	LEFT JOIN MasterRepuestosPolarisDescuento d on A.codigo = d.CodeDiscount
   WHERE C.Estacion = @EstacionTrabajo           
            
  INSERT INTO PC          
      (Empresa, Mov, MovID, FechaEmision, UltimoCambio, Concepto, Moneda, Proyecto, TipoCambio, Usuario, Autorizacion,          
       DocFuente, Observaciones, Estatus, Situacion, Referencia, SituacionFecha, OrigenTipo, Origen, OrigenID, Ejercicio,          
       Periodo, FechaRegistro, FechaConclusion, FechaCancelacion, Poliza, PolizaID, GenerarPoliza, ContID, Sucursal,           
       ListaModificar, FechaInicio, FechaTermino, Recalcular, Parcial, SucursalOrigen, SucursalDestino, UEN)          
  VALUES          
     (@Empresa, 'Precios', NULL, getdate(), getdate(), NULL, 'Dolar', NULL, 1.0, @Usuario, NULL,          
       NULL,'DESDE INTERFAZ POLARIS', 'SINAFECTAR', NULL, NULL, NULL, NULL, NULL, NULL, NULL,           
       NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, @Sucursal,           
       '(Precio 2)', NULL, NULL, 0, 1, @Sucursal, NULL, NULL)          
            
  SELECT @IDPrecio = @@IDENTITY           
            
  INSERT INTO MovTiempo           
(Modulo, ID, FechaComenzo, FechaInicio, Estatus, Situacion)            
  VALUES           
  ('PC', @IDPrecio, GETDATE(), GETDATE(), 'SINAFECTAR', NULL)           
              
  INSERT INTO PCD          
          (ID     , Renglon, Articulo, SubCuenta, Unidad, Anterior, Nuevo, Sucursal  ,SucursalOrigen,Baja)          
  SELECT @IDPrecio, Renglon, Articulo, NULL     , Unidad, Anterior, Nuevo, @Sucursal ,@Sucursal     ,0          
    FROM #PCDTemp          
            
  EXEC spAfectar 'PC', @IDPrecio, 'AFECTAR', 'Todo', NULL, @Usuario, @EnSilencio = 1          
            
  SELECT @IDPrecio = NULL          
          
-- ACTUALIZAR PRECIO AEREO            
  TRUNCATE TABLE #PCDTemp          
            
  INSERT #PCDTemp           
        ( Articulo , Anterior, Nuevo)          
SELECT A.Articulo , null,          
         Round(Precio * Distributornet,2)           
    FROM MasterRepuestosPolaris            A          
    JOIN Art          B ON A.Articulo        = B.Articulo          
    JOIN AltaArticuloPolaris               C ON A.Articulo        = C.Articulo                
	LEFT JOIN MasterRepuestosPolarisDescuento d on A.codigo = d.CodeDiscount
   WHERE C.Estacion = @EstacionTrabajo           
                   
  
  INSERT INTO PC          
      (Empresa, Mov, MovID, FechaEmision, UltimoCambio, Concepto, Moneda, Proyecto, TipoCambio, Usuario, Autorizacion,          
       DocFuente, Observaciones, Estatus, Situacion, Referencia, SituacionFecha, OrigenTipo, Origen, OrigenID, Ejercicio,          
       Periodo, FechaRegistro, FechaConclusion, FechaCancelacion, Poliza, PolizaID, GenerarPoliza, ContID, Sucursal,           
       ListaModificar, FechaInicio, FechaTermino, Recalcular, Parcial, SucursalOrigen, SucursalDestino, UEN)          
  VALUES          
     (@Empresa, 'Precios', NULL, getdate(), getdate(), NULL, 'Dolar', NULL, 1.0, @Usuario, NULL,          
       NULL,'DESDE INTERFAZ POLARIS', 'SINAFECTAR', NULL, NULL, NULL, NULL, NULL, NULL, NULL,           
       NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, @Sucursal,           
       '(Precio 3)', NULL, NULL, 0, 1, @Sucursal, NULL, NULL)          
            
  SELECT @IDPrecio = @@IDENTITY           
            
  INSERT INTO MovTiempo           
  (Modulo, ID, FechaComenzo, FechaInicio, Estatus, Situacion)            
  VALUES           
  ('PC', @IDPrecio, GETDATE(), GETDATE(), 'SINAFECTAR', NULL)           
              
  INSERT INTO PCD          
          (ID     , Renglon, Articulo, SubCuenta, Unidad, Anterior, Nuevo, Sucursal  ,SucursalOrigen,Baja)          
  SELECT @IDPrecio, Renglon, Articulo, NULL     , Unidad, Anterior, Nuevo, @Sucursal ,@Sucursal     ,0          
    FROM #PCDTemp          
            
  EXEC spAfectar 'PC', @IDPrecio, 'AFECTAR', 'Todo', NULL, @Usuario, @EnSilencio = 1          
            
  SELECT @IDPrecio = NULL          
            
-- ACTUALIZAR PRECIO MARITIMO          
  TRUNCATE TABLE #PCDTemp          
            
  INSERT #PCDTemp           
        ( Articulo , Anterior, Nuevo)          
 SELECT A.Articulo , null,          
         Round(Precio * Distributornet,2)        
    FROM MasterRepuestosPolaris            A          
    JOIN Art          B ON A.Articulo        = B.Articulo          
    JOIN AltaArticuloPolaris               C ON A.Articulo        = C.Articulo  
	LEFT JOIN MasterRepuestosPolarisDescuento d on A.codigo = d.CodeDiscount              
   WHERE C.Estacion = @EstacionTrabajo           
            
  INSERT INTO PC          
      (Empresa, Mov, MovID, FechaEmision, UltimoCambio, Concepto, Moneda, Proyecto, TipoCambio, Usuario, Autorizacion,          
       DocFuente, Observaciones, Estatus, Situacion, Referencia, SituacionFecha, OrigenTipo, Origen, OrigenID, Ejercicio,          
       Periodo, FechaRegistro, FechaConclusion, FechaCancelacion, Poliza, PolizaID, GenerarPoliza, ContID, Sucursal,           
       ListaModificar, FechaInicio, FechaTermino, Recalcular, Parcial, SucursalOrigen, SucursalDestino, UEN)          
  VALUES          
     (@Empresa, 'Precios', NULL, getdate(), getdate(), NULL, 'Dolar', NULL, 1.0, @Usuario, NULL,          
       NULL,'DESDE INTERFAZ POLARIS', 'SINAFECTAR', NULL, NULL, NULL, NULL, NULL, NULL, NULL,           
       NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, @Sucursal,           
       '(Precio 4)', NULL, NULL, 0, 1, @Sucursal, NULL, NULL)          
            
  SELECT @IDPrecio = @@IDENTITY           
            
  INSERT INTO MovTiempo           
  (Modulo, ID, FechaComenzo, FechaInicio, Estatus, Situacion)            
  VALUES           
  ('PC', @IDPrecio, GETDATE(), GETDATE(), 'SINAFECTAR', NULL)           
              
  INSERT INTO PCD          
          (ID     , Renglon, Articulo, SubCuenta, Unidad, Anterior, Nuevo, Sucursal  ,SucursalOrigen,Baja)          
  SELECT @IDPrecio, Renglon, Articulo, NULL     , Unidad, Anterior, Nuevo, @Sucursal ,@Sucursal     ,0          
    FROM #PCDTemp          
            
  EXEC spAfectar 'PC', @IDPrecio, 'AFECTAR', 'Todo', NULL, @Usuario, @EnSilencio = 1          
            
  DELETE           
    FROM AltaArticuloPolaris          
   WHERE Estacion = @EstacionTrabajo          
            
  SELECT 'Se Agregaron al Catalogo de Articulos ' + CONVERT(varchar, @@ROWCOUNT) + ' Piezas del Master de Articulos'          
             
  RETURN          
END   
  
  
GO

