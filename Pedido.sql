DROP PROCEDURE [dbo].[spGenerarPedidoCotizadorPolaris]
GO
  
SET DATEFIRST 7
SET ANSI_NULLS OFF
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET LOCK_TIMEOUT -1
SET QUOTED_IDENTIFIER OFF
 
GO
/*************************** PROCEDIMIENTO GENERAR PEDIDO COTIZADOR POLARIS ****************************************************/  
  
/****** Object:  StoredProcedure [dbo].[spGenerarPedidoCotizadorPolaris]    Script Date: 20/02/2017 16:40:40 ******/  
  
  
CREATE PROCEDURE [dbo].[spGenerarPedidoCotizadorPolaris]       
 @ID INT,    
 @TipoCalculo INT  ,  
 @Estacion int   
--WITH ENCRYPTION     
AS    
BEGIN    
DECLARE    
  @Empresa varchar(10),    
  @Usuario varchar(50),    
  @Cliente varchar(10),    
  @Sucursal int,    
  @PrecioDHL float,    
  @PrecioAereo float,    
  @PrecioMaritimo float,    
  @Precio float,    
  @Articulo varchar(100),    
  @Cantidad int,    
  @TipoCambio float,    
  @IDVenta int,    
  @Agente varchar(15),    
  @Almacen varchar(4),    
  @FechaEmision Date,    
  @ListaPreciosEsp VARCHAR(20),    
  @Renglon int,    
  @RenglonID int,    
  @MonedaTC float,    
  @Descripcion varchar(255),    
  @Ok INT  = NULL,    
  @OkRef VARCHAR(255) = NULL,    
  @MovID varchar(10),    
  @Generado int,    
  @IDCompra int ,  
  @Refe  varchar(255),
  @PrecioDescuento float   
     
    
    
    
 SELECT  @Empresa = Empresa,    
         @Sucursal = Sucursal,    
         @Usuario = Usuario,    
         @Cliente = Cliente,    
         @FechaEmision = FechaEmision,    
         @MonedaTC = TipoCambio ,  
   @Refe = ORDEN,  
   @Agente = Agente   
  
FROM CotizacionMasterPolaris     
  WHERE ID= @ID    
    
 SELECT @Agente = DefAgente,     
        @Almacen = DefAlmacen     
  FROM Usuario     
  WHERE Usuario = @Usuario    
      
        IF (@TipoCalculo = 1)     
           SELECT @ListaPreciosEsp = '(Precio 2)'    
        IF (@TipoCalculo = 2)     
           SELECT @ListaPreciosEsp = '(Precio 3)'    
        IF (@TipoCalculo = 3)     
           SELECT @ListaPreciosEsp = '(Precio 4)'    
               
 -- INICIA CREAR COTIZACION REPUESTOS    
 BEGIN TRANSACTION    
    INSERT Venta              
             (Sucursal,SucursalOrigen, Empresa, Mov, FechaEmision, FechaRequerida, FechaRegistro, Moneda, TipoCambio, Almacen, Cliente,             
               Concepto, Usuario, Estatus, Agente, Referencia, ListaPreciosEsp,Contuso)               
      VALUES (@Sucursal, @Sucursal,'BAVAR', 'Cotización Repuestos', @FechaEmision, @FechaEmision,  GETDATE(), 'Quetzales', 1,  ISNULL(@Almacen,'141S'), @Cliente,             
               'Publico', @Usuario, 'SINAFECTAR', @Agente, @Refe, @ListaPreciosEsp,'101-04-01')             
                               
      SELECT @IDVenta = @@IDENTITY     
      SELECT @RenglonID = 1    
      SELECT @Generado = 0    
    INSERT MovTiempo              
               (Modulo,ID,FechaComenzo,FechaInicio,Estatus,Situacion)              
        VALUES ('VTAS',@IDVenta,GETDATE(),GETDATE(),'SINAFECTAR',NULL)      
    
DECLARE crExtraeDatos CURSOR LOCAL    
   FOR    
      SELECT  Renglon,Articulo,Cantidad,PrecioDHL,PrecioAereo,PrecioMaritimo      
      from CotizacionMasterPolarisDetalle WHERE ID= @ID    
    
  open crExtraeDatos    
   FETCH NEXT    
   FROM crExtraeDatos    
   INTO @Renglon,@Articulo,@Cantidad,@PrecioDHL,@PrecioAereo,@PrecioMaritimo     
    WHILE @@FETCH_STATUS <> - 1    
    AND @Renglon IS NOT NULL    
        BEGIN    
           IF (@TipoCalculo = 1)     
             SELECT @Precio = @PrecioDHL     
           IF (@TipoCalculo = 2)     
             SELECT @Precio = @PrecioAereo     
           IF (@TipoCalculo = 3)     
             SELECT @Precio = @PrecioMaritimo     
           
             
        INSERT VentaD               
               (ID, Renglon,RenglonID,RenglonTipo,Almacen,Codigo,Articulo,SubCuenta,Cantidad,Precio,PrecioSugerido,               
                DescuentoTipo,DescuentoLinea,DescuentoImporte ,Impuesto1,Impuesto2,Impuesto3,DescripcionExtra,               
                ContUso ,Factor , Unidad, FechaRequerida,Agente,Sucursal,SucursalOrigen, PrecioMoneda,PrecioTipoCambio,Costo,tipoimpuesto1)               
        VALUES (@IDVenta,@Renglon, @RenglonID,'N',ISNULL(@Almacen,'141S'),@Articulo,@Articulo,'',@Cantidad,@Precio*@MonedaTC,@Precio*@MonedaTC,              
                NULL ,  0.0  ,  0.0  ,  12.0  ,  0.0  ,  0.0  ,  NULL  ,               
               NULL , 1.0  , 'pza', @FechaEmision, @Agente,@Sucursal , @Sucursal, 'Dolar',  @MonedaTC, 0,'IVA')     
                   
           
           
        SELECT @RenglonID = @RenglonID + 1    
        -- CREAR ARTICULO SI NO EXISTE    
          
        IF NOT EXISTS(SELECT ARTICULO FROM ART WHERE ARTICULO = @Articulo)    
         BEGIN    
         SELECT @PrecioDescuento = Round(M.Precio * D.Distributornet,2),@Descripcion= Descripcion from MasterRepuestosPolaris M
         LEFT OUTER JOIN MasterRepuestosPolarisDescuento d on M.codigo = d.CodeDiscount
         where Articulo =  @Articulo    
             
         Insert Art(Articulo, Descripcion1, Tipo , Unidad, MonedaPrecio, Impuesto1, TipoImpuesto1, Presentacion, PrecioLista, Categoria, Observaciones, MonedaCosto,Estatus, UnidadCompra ,Fabricante,UnidadTraspaso)    
         values (@Articulo, @Descripcion, 'Normal', 'pza', 'Dolar', '12','IVA','GENERICO',@Precio,'01-REPUESTOS PARA VEHICULOS', 'CREADO AUTOMATICAMENTE DESDE COTIZADOR POLARIS','Quetzales','ALTA','pza','Polaris','pza')    
         SELECT @Generado = @Generado + 1     
      END     
   
        FETCH NEXT    
    FROM crExtraeDatos    
    INTO  @Renglon,@Articulo,@Cantidad,@PrecioDHL,@PrecioAereo,@PrecioMaritimo     
   END    
    
   CLOSE crExtraeDatos    
    
   DEALLOCATE crExtraeDatos    
 -- FINALIZA CREAR PEDIDO REPUESTOS    
     
 --AFECTAR PEDIDO    
    
    
 EXEC spAfectar 'VTAS', @IDVenta, 'AFECTAR', 'TODO', NULL, @Usuario, @EnSilencio = 1, @Ok = @Ok OUTPUT, @OkRef = @OkRef OUTPUT, @Conexion = 1             
 SELECT @MovID = MovID FROM Venta WHERE ID = @IDVenta    
 UPDATE VENTAD SET CantidadA = Cantidad WHERE ID = @IDVenta    
    
    
 --Crear Requisicion Compras    
   /*DECLARE      
          
        @FechaRequerida  datetime   ,      
        @OrigenTipo      varchar(20),      
        @Origen          varchar(20),      
        @OrigenID        varchar(20),      
        @GenerarMov      varchar(20),      
        @GenerarMovID    varchar(20),      
        @Concepto        varchar(50),      
        @EsServicio      bit        ,      
        @Mensaje         varchar(20),    
  @MovIDCompras varchar(10)    
      
  SELECT @FechaEmision   = CONVERT(datetime, FLOOR(CONVERT(float, GETDATE()))),      
         @OrigenTipo     = 'VTAS'       ,      
         @Origen         = V.Mov        ,      
         @OrigenID       = V.MovID      ,      
         @GenerarMov     = 'Requisicion',      
         @Almacen        = V.Almacen    ,      
         @Agente         = V.Agente     ,      
         @Concepto       = 'Proveedores del Exterior',      
         @Cliente        = V.Cliente    ,      
         @FechaRequerida = V.FechaEmision,       
         @EsServicio     = CASE WHEN Sucursal = 106 THEN 1 ELSE 0 END      
    FROM Venta V      
   WHERE V.ID =  @IDVenta    
    
    
 SELECT  @ListaPreciosEsp = ListaPreciosEsp FROM VENTA WHERE ID = @IDVenta     
    
     IF (@ListaPreciosEsp = '(Precio 2)')     
           SELECT @ListaPreciosEsp = 'PRECIO DHL'    
     IF (@ListaPreciosEsp = '(Precio 3)')     
           SELECT @ListaPreciosEsp = 'PRECIO AEREO'    
     IF (@ListaPreciosEsp = '(Precio 4)')     
           SELECT @ListaPreciosEsp = 'PRECIO MARITIMO'    
          
              
  INSERT Compra       
        ( UltimoCambio, Sucursal , SucursalOrigen, SucursalDestino,                                  OrigenTipo,  Origen,  OrigenID,  Empresa,        
          Usuario,  Estatus     ,  Mov,         MovID,         FechaEmision, Directo,  Almacen,  Concepto, Moneda,  TipoCambio,  Referencia,       
          FechaRequerida, Agente, Cliente,Observaciones)      
  SELECT  GETDATE()   , 105      , @Sucursal     , CASE WHEN @EsServicio = 1 THEN 106 ELSE 105 END, @OrigenTipo, @Origen, @OrigenID, @Empresa,       
          @Usuario, 'SINAFECTAR', @GenerarMov, @GenerarMovID, @FechaEmision, 1 , @Almacen, @Concepto, 'Quetzales', 1, 'Polaris '+ RTRIM(@Origen)+' '+RTRIM(@OrigenID),       
          @FechaRequerida,@Agente, @Cliente,@ListaPreciosEsp     
        
  SELECT @IDCompra = @@IDENTITY      
        
  INSERT CompraD       
        ( Sucursal, ID      , Renglon, RenglonSub, RenglonID, RenglonTipo, Articulo, SubCuenta, Almacen ,  Cantidad, Unidad, FechaRequerida,       
          Impuesto1, Impuesto2, Impuesto3, DestinoTipo, Destino, DestinoID, ModuloPedidoEspecial, IDPedidoEspecial, MovPedidoEspecial, MovIDPedidoEspecial, RenglonPE, RenglonIDPE,     
          RenglonSubPE )      
  SELECT @Sucursal,@IDCompra, Renglon, RenglonSub, RenglonID, RenglonTipo, Articulo, SubCuenta, @Almacen,  CantidadA, Unidad,@FechaRequerida,       
          Impuesto1, Impuesto2, Impuesto3, @OrigenTipo, @Origen, @OrigenID, 'VTAS', @IDVenta,  @Origen, @OrigenID, Renglon, RenglonID, RenglonSub    
    FROM VentaD      
   WHERE ID = @IDVenta    
     AND CantidadA IS NOT NULL      
     AND ISNULL(Cantidad,0) <> (ISNULL(CantidadOrdenada,0)+ISNULL(CantidadReservada,0)+ISNULL(CantidadCancelada,0))      
     AND ISNULL(CantidadPendiente,0)>= ISNULL(CantidadA,0)    
          
   EXEC spAfectar 'COMS', @IDCompra, 'AFECTAR', 'TODO', NULL, @Usuario, @EnSilencio = 1, @Ok = @Ok OUTPUT, @OkRef = @OkRef OUTPUT, @Conexion = 1        
       
   SELECT @MovIDCompras = MovID FROM Compra WHERE ID = @IDCompra    
         
-- Finaliza Crear Requisicion Compras */   
     
     IF  @Ok is NULL    
     BEGIN    
      COMMIT TRANSACTION    
 -- set @Refe=CONCAT('Cotizacion Polaris ',@ID)  
       UPDATE CotizacionMasterPolaris SET ESTATUS = 'CONCLUIDO',IDVentas= @IDVenta,IDCompras= @IDCompra WHERE ID = @ID    
    exec spVentaRepCteD @Estacion, @Empresa,@Cliente,@Refe  
     IF @Generado = 0    
   SELECT 'Se Generó Cotización Repuestos ' + @MovID -- + '<BR>Se Generó Requisición ' + @MovIDCompras    
    
   ELSE     
     SELECT 'Se Generó Cotización Repuestos ' + @MovID  /*+ '<BR>Se Generó Requisición ' + @MovIDCompras +'<BR>'+ CAST(@Generado AS VARCHAR(5))*/+ ' Articulo(s) Creado(s) Automáticamente'    
     END    
         
     ELSE     
     BEGIN    
     ROLLBACK TRANSACTION    
      SELECT Descripcion + ISNULL(RTRIM(@OkRef), '') FROM MensajeLista WHERE Mensaje = @Ok             
     END    
          
END    
