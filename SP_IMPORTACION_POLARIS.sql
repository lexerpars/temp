SET DATEFIRST 7
SET ANSI_NULLS OFF
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET LOCK_TIMEOUT - 1
SET QUOTED_IDENTIFIER OFF
GO

IF EXISTS (
  SELECT *
  FROM sysobjects
  WHERE id = object_id('SP_IMPORTACION_POLARIS')
   AND type = 'P'
  )
 DROP PROCEDURE dbo.[SP_IMPORTACION_POLARIS]
GO
  
  
CREATE PROCEDURE [dbo].[SP_IMPORTACION_POLARIS]                 
        @Estacion              int        ,                
        @Empresa               varchar( 5),                
        @Usuario               varchar(10),                
        @Sucursal              int          
     --   @Ruta                  varchar(255)           
AS                
BEGIN                
  DECLARE                
        @Datos                 nvarchar(max),              
        @DatosDesglose         varchar (256),              
        @LargoDeRegistro       int          ,              
        @ConteoRegistros       int          ,            
        @CantidadActualizada   int          ,            
        @ConteoLetras          int          ,            
        @IDCosto               int          ,            
        @IDPrecio              int          ,            
        @TCEuros               float        ,            
        @TCDolares             float        ,            
        @Inicio                int          ,          
        @Conversion            varchar(8)   
    
  
    
  --SELECCIONAR TIPO DE CAMBIO EN EUROS Y DOLARES  
  --SELECT @TCEUROS=ISNULL(TIPOCAMBIO,0) FROM MON WHERE MONEDA='Euros'  
  SELECT @TCDolares=ISNULL(TIPOCAMBIO,0) FROM MON WHERE MONEDA='Dolar'  
      
  CREATE TABLE #TempArticulo            
      (             
        Articulo       varchar(20),        
        Precio      varchar (8) null,         
        ClaveDescuento    varchar(1) null,    
        keyfigurelistaprecioespecial varchar(1) null,      
       ) 
	         
       
   CREATE TABLE #PCDTemp          
      (           
        Renglon        int   identity(2048,2048),          
        Articulo       varchar(20),          
        Anterior       float       NULL,          
        Nuevo          money      ,          
        Unidad         varchar(50) NULL          
       )      
  
    
  INSERT #TempArticulo   
      (Articulo,Precio)  
  SELECT SUBSTRING(DATOS,1,13),SUBSTRING(DATOS,47,8) FROM LISTADATOSPOLARIS  
  
 DELETE FROM  MasterRepuestosPolaris where Articulo in (SELECT Articulo from #TempArticulo)  
  
  INSERT INTO MasterRepuestosPolaris(ARTICULO,DESCRIPCION,CODIGO,PRECIO,REFERENCIA,UNIDAD,CLASE,SNOWMOBILE,ATV,PWC,VICTORY,RANGER,PPS,POLARIS_POWER,BOATS,LEV,MIL,MOTOCICLETAS_INDIAN,RZR,SLINGSHOT)  
  SELECT SUBSTRING(DATOS,1,13),SUBSTRING(DATOS,14,31),SUBSTRING(DATOS,45,2),SUBSTRING(DATOS,47,8) ,SUBSTRING(DATOS,55,9),SUBSTRING(DATOS,64,3),  
  SUBSTRING(DATOS,67,2),SUBSTRING(DATOS,69,1),SUBSTRING(DATOS,70,1), SUBSTRING(DATOS,71,1), SUBSTRING(DATOS,72,1), SUBSTRING(DATOS,73,1),  
  SUBSTRING(DATOS,74,1),SUBSTRING(DATOS,75,1),SUBSTRING(DATOS,76,1),SUBSTRING(DATOS,77,1),SUBSTRING(DATOS,78,1),SUBSTRING(DATOS,79,1),  
  SUBSTRING(DATOS,80,1),SUBSTRING(DATOS,81,1) FROM LISTADATOSPOLARIS  
  
  
  SELECT @ConteoRegistros = @@ROWCOUNT  
  UPDATE MasterRepuestosPolaris SET PRECIO= CAST((CAST(Precio AS FLOAT)*0.01) AS VARCHAR)  WHERE PRECIO NOT LIKE '%TBA%' AND ARTICULO IN (SELECT ARTICULO FROM #TEMPARTICULO)  
  
  --ACTUALIZAR PRECIO DHL  
  INSERT #PCDTemp             
        ( Articulo , Anterior, Nuevo)            
  SELECT A.Articulo , null,            
         dbo.fnCalcularPreciosPolaris(A.Articulo, @TCDolares, 1 )            
    FROM #TempArticulo                 A            
    JOIN Art                           B ON A.Articulo        = B.Articulo                    
              
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
         dbo.fnCalcularPreciosPolaris(A.Articulo, @TCDolares, 2 )            
    FROM #TempArticulo                 A            
    JOIN Art                           B ON A.Articulo        = B.Articulo           
                
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
         dbo.fnCalcularPreciosPolaris(A.Articulo, @TCDolares, 3 )            
    FROM #TempArticulo                 A            
    JOIN Art                           B ON A.Articulo        = B.Articulo             
              
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
              
 /* IF @CantidadActualizada IS NULL               
    SELECT @CantidadActualizada = 0            */  
                  
  SELECT 'SE ACTUALIZARON ' + CONVERT(varchar,@ConteoRegistros) + ' PIEZAS DEL MASTER DE ARTICULOS.'            
    
delete listadatospolaris where estacion = @Estacion  
--SE ACTUALIZARON ' + CONVERT(varchar,@CantidadActualizada) + ' PRECIOS.'            
    
  RETURN   
  
END  
