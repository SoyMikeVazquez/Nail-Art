-- ============================================================================
-- SCRIPT DE INICIALIZACIÓN COMPLETA PARA LA BASE DE DATOS DE NAIL ART
-- Copia y pega este script completo en el Editor SQL de tu consola de Supabase y ejecútalo.
-- ============================================================================

-- Habilitar extensión pgcrypto si no está habilitada
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Limpiar tablas previas para asegurar una creación limpia desde cero
DROP TABLE IF EXISTS public."Citas" CASCADE;
DROP TABLE IF EXISTS public."Cursos" CASCADE;
DROP TABLE IF EXISTS public."Eventos" CASCADE;
DROP TABLE IF EXISTS public."FinanzasPersonal" CASCADE;
DROP TABLE IF EXISTS public."InventarioDiario" CASCADE;
DROP TABLE IF EXISTS public."OrdenesProductos" CASCADE;
DROP TABLE IF EXISTS public."Proveedores" CASCADE;
DROP TABLE IF EXISTS public."ProveedoresStock" CASCADE;
DROP TABLE IF EXISTS public."PedidosProveedores" CASCADE;
DROP TABLE IF EXISTS public."Secrets" CASCADE;
DROP TABLE IF EXISTS public."Services" CASCADE;
DROP TABLE IF EXISTS public.clientes CASCADE;
DROP TABLE IF EXISTS public."General" CASCADE;
DROP TABLE IF EXISTS public."Participantes" CASCADE;
DROP TABLE IF EXISTS public."VisitasyRecurrencia" CASCADE;
DROP TABLE IF EXISTS public."Personal" CASCADE;
DROP TABLE IF EXISTS public."Productos" CASCADE;
DROP TABLE IF EXISTS public."Sucursales" CASCADE;
DROP TABLE IF EXISTS public.users CASCADE;

-- ============================================================================
-- 1. TABLAS BASE Y DE ENTIDAD
-- ============================================================================

-- Tabla: users
CREATE TABLE IF NOT EXISTS public.users (
    "IDUser" uuid PRIMARY KEY,
    "NombreCompleto" text,
    "nombre" text,
    "correo" text,
    "Telefono" text,
    "whatsapp" text,
    "certificaciones" text,
    "isPersonal" boolean DEFAULT false,
    "isAdmin" boolean DEFAULT false,
    "isGestor" boolean DEFAULT false,
    "isRecepcion" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT timezone('utc'::text, now()),
    "hora_entrada" time without time zone,
    "hora_salida" time without time zone,
    "hora_descanso_inicio" time without time zone,
    "hora_descanso_fin" time without time zone,
    "sucursal" text
);

-- Tabla: Sucursales
CREATE TABLE IF NOT EXISTS public."Sucursales" (
    "IDSucursal" text PRIMARY KEY,
    "NombreSucursal" text NOT NULL,
    "IDSucursales" text,
    "created_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Tabla: Personal
CREATE TABLE IF NOT EXISTS public."Personal" (
    "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    "userID" uuid REFERENCES public.users("IDUser") ON DELETE CASCADE,
    "nombre" text,
    "NombrePersonal" text,
    "telefono" text,
    "WhatsApp-Numero" text,
    "correo" text,
    "sucursal" text,
    "Sucursal" text,
    "horarios" text,
    "foto_perfil" text,
    "FotoEmpleado" text,
    "mostrar_foto" boolean DEFAULT true,
    "servicios_ids" text[],
    "tiene_certificado" boolean DEFAULT false,
    "certificado_nombre" text,
    "certificado_cedula" text,
    "certificado_avalacion" text,
    "TipoPersonal" text,
    "created_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT timezone('utc'::text, now())
);

-- Tabla: Productos
CREATE TABLE IF NOT EXISTS public."Productos" (
    "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    "nombre" text,
    "NombreProducto" text,
    "descripcion" text,
    "DescripciónProducto" text,
    "precio" numeric DEFAULT 0,
    "montoProducto" numeric DEFAULT 0,
    "stock" integer DEFAULT 0,
    "cantidadInventario" integer DEFAULT 0,
    "categoria" text,
    "Categoria" text,
    "imagen_url" text,
    "ImagenProducto" text,
    "marca" text,
    "en_oferta" boolean DEFAULT false,
    "descuento_porcentual" numeric DEFAULT 0,
    "IDProductos" text,
    "cupones_aplicables" text[],
    "contacto_proveedor" text,
    "disponible_venta" boolean DEFAULT true,
    "isDisponibleVenta" boolean DEFAULT true,
    "porcentaje_venta_personal" numeric DEFAULT 0,
    "created_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Tabla: clientes
CREATE TABLE IF NOT EXISTS public.clientes (
    "IDCliente" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    "nombre" text NOT NULL,
    "telefono" text,
    "correo" text,
    "notas" text,
    "sucursal_preferida" text,
    "puntos" integer DEFAULT 0,
    "puntos_meta" integer DEFAULT 0,
    "puntos_apertura" timestamp with time zone DEFAULT timezone('utc'::text, now()),
    "ultimo_canjeo" timestamp with time zone,
    "qr_token" text,
    "created_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- ============================================================================
-- 2. TABLAS OPERATIVAS Y DEL NEGOCIO
-- ============================================================================

-- Tabla: Citas
CREATE TABLE IF NOT EXISTS public."Citas" (
    "clienteID" uuid REFERENCES public.clientes("IDCliente") ON DELETE CASCADE NOT NULL,
    "barberoID" uuid REFERENCES public.users("IDUser") ON DELETE SET NULL NOT NULL,
    "servicioID" uuid NOT NULL,
    "fecha" date NOT NULL,
    "horaInicio" time without time zone NOT NULL,
    "horaFin" time without time zone,
    "sucursal" text,
    "estatus" text,
    "precioFinal" numeric,
    "Servicios" text,
    "Personal" text,
    "NombreCliente" text,
    "CorreoCliente" text,
    "NumeroTelefonoCliente" text,
    "NumeroTelefonoC" text,
    "Sucursal" text,
    "MontoACobrar" numeric,
    "sucursal_id" text,
    "created_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    PRIMARY KEY ("clienteID", "barberoID", "servicioID", "fecha", "horaInicio")
);

-- Tabla: Cursos
CREATE TABLE IF NOT EXISTS public."Cursos" (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    "NombreDelCurso" text NOT NULL,
    "DescripcionCorta" text,
    "DescripcionLarga" text,
    "ImagenPortada" text,
    "PrecioFinal" numeric,
    "Anticipo" numeric,
    "Descuento" numeric,
    "FechaDelInicio" date,
    "isDisponible" boolean DEFAULT true,
    "DatosDePago" text,
    "created_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Tabla: Eventos
CREATE TABLE IF NOT EXISTS public."Eventos" (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    "imagenDeEvento" text,
    "TituloDeEvento" text NOT NULL,
    "DescripcionDelEvento" text,
    "FechaDeEvento" timestamp with time zone,
    "FechaEnQueFinalizo" timestamp with time zone,
    "IDdeEvento" text,
    "FechaYaNoVerNuevoEvento" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Tabla: FinanzasPersonal
CREATE TABLE IF NOT EXISTS public."FinanzasPersonal" (
    "personalID" text NOT NULL,
    "fecha" timestamp with time zone NOT NULL,
    "servicios_ids" text[],
    "servicios_detalle" jsonb,
    "suma_servicios" numeric DEFAULT 0,
    "montos_extras" numeric DEFAULT 0,
    "descripcion_extras" text,
    "total" numeric DEFAULT 0,
    "formadepago" text,
    "sucursal" text,
    "QuienRegistro" text,
    "Gasto" text,
    "sucursal_id" text,
    "cliente_id" uuid,
    "cliente_email" text,
    "cliente_telefono" text,
    "cliente_nombre" text,
    "created_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    PRIMARY KEY ("personalID", "fecha")
);
CREATE INDEX IF NOT EXISTS idx_finanzaspersonal_personal_id ON public."FinanzasPersonal" ("personalID");

-- Tabla: InventarioDiario
CREATE TABLE IF NOT EXISTS public."InventarioDiario" (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    "producto_id" uuid REFERENCES public."Productos"("id") ON DELETE CASCADE,
    "nombre_producto" text NOT NULL,
    "stock" integer DEFAULT 0,
    "fecha" date NOT NULL,
    "asignacion_personal" jsonb,
    "created_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT "unique_product_daily" UNIQUE ("producto_id", "fecha")
);

-- Tabla: OrdenesProductos
CREATE TABLE IF NOT EXISTS public."OrdenesProductos" (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    "personal_id" uuid,
    "productos_detalle" jsonb,
    "suma_productos" numeric DEFAULT 0,
    "formadepago" text,
    "sucursal" text,
    "fecha" timestamp with time zone,
    "QuienRegistro" text,
    "sucursal_id" text,
    "cliente_id" uuid,
    "cliente_email" text,
    "cliente_telefono" text,
    "cliente_nombre" text,
    "created_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Tabla: Proveedores
CREATE TABLE IF NOT EXISTS public."Proveedores" (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    "nombre" text NOT NULL,
    "contacto" text,
    "categoria" text,
    "metodos_pago" text,
    "dias_credito" integer DEFAULT 0,
    "precio_total_pedido" numeric DEFAULT 0,
    "productos_ids" jsonb DEFAULT '[]'::jsonb NOT NULL,
    "created_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Tabla: ProveedoresStock
CREATE TABLE IF NOT EXISTS public."ProveedoresStock" (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    "producto_id" uuid REFERENCES public."Productos"("id") ON DELETE CASCADE,
    "proveedor" text NOT NULL,
    "cantidad" integer NOT NULL,
    "costo_unitario" numeric DEFAULT 0.0 NOT NULL,
    "fecha" date NOT NULL,
    "created_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Tabla: Secrets
CREATE TABLE IF NOT EXISTS public."Secrets" (
    key text PRIMARY KEY,
    value text NOT NULL,
    description text,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Tabla: Services
CREATE TABLE IF NOT EXISTS public."Services" (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    "nameService" text NOT NULL,
    "descriptionService" text,
    "ImageService" text,
    "imageListServices" text[],
    "IDServices" text,
    "Price" numeric DEFAULT 0,
    "Prince2" numeric DEFAULT 0,
    "Price3" numeric DEFAULT 0,
    "tiempo_servicio" integer,
    "PrecioPremium" numeric,
    "created_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Tabla: General
CREATE TABLE IF NOT EXISTS public."General" (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    "NumerodeUsuarios" integer DEFAULT 0,
    "IDEmpresa" text,
    "NombreDeLaEmpresa" text,
    "LogoDeLaEmpresa" text,
    "imagePortada" text,
    "RecompensaTituloPuntos" text,
    "RecompensaDescripcionPuntos" text,
    "BLOQUEOAPP" boolean DEFAULT false,
    "Giro" text,
    "PUNTOSALCOMPLETAR" integer DEFAULT 6,
    "ElimCuenta" boolean DEFAULT false,
    "PoliticaDePrivacidad" text,
    "Soporte" text,
    "completado" boolean DEFAULT false,
    "verPreciosServicios" boolean DEFAULT true,
    "verPreciosProductos" boolean DEFAULT true,
    "urlVideo" text,
    "correoNotificacionesGeneral" text,
    "imagenSlider1" text,
    "imagenSlider2" text,
    "imagenSlider3" text
);

-- Tabla: Participantes
CREATE TABLE IF NOT EXISTS public."Participantes" (
    "userID" uuid PRIMARY KEY REFERENCES public.users("IDUser") ON DELETE CASCADE,
    "nombre" text,
    "created_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Tabla: VisitasyRecurrencia
CREATE TABLE IF NOT EXISTS public."VisitasyRecurrencia" (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    "evento" jsonb NOT NULL,
    "created_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Tabla: PedidosProveedores
CREATE TABLE IF NOT EXISTS public."PedidosProveedores" (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    "fecha_pedido" date DEFAULT current_date NOT NULL,
    "proveedor_id" uuid REFERENCES public."Proveedores"("id") ON DELETE SET NULL,
    "nombre_proveedor" text NOT NULL,
    "total_pagar" double precision DEFAULT 0.0 NOT NULL,
    "plazo_pago" integer DEFAULT 0 NOT NULL,
    "url_factura" text,
    "metodo_pago" text,
    "meses_sin_intereses" integer DEFAULT 0 NOT NULL,
    "deuda" double precision DEFAULT 0.0 NOT NULL,
    "completado" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);


-- ============================================================================
-- 3. TRIGGERS DE SINCRONIZACIÓN DE CAMPOS (COMPATIBILIDAD)
-- ============================================================================

-- Trigger para public.users
CREATE OR REPLACE FUNCTION sync_users_fields()
RETURNS TRIGGER AS $$
BEGIN
    -- NombreCompleto <-> nombre
    IF NEW."NombreCompleto" IS NOT NULL AND (OLD."NombreCompleto" IS NULL OR NEW."NombreCompleto" <> OLD."NombreCompleto") THEN
        NEW."nombre" := NEW."NombreCompleto";
    ELSIF NEW."nombre" IS NOT NULL AND (OLD."nombre" IS NULL OR NEW."nombre" <> OLD."nombre") THEN
        NEW."NombreCompleto" := NEW."nombre";
    END IF;

    -- Telefono <-> whatsapp
    IF NEW."Telefono" IS NOT NULL AND (OLD."Telefono" IS NULL OR NEW."Telefono" <> OLD."Telefono") THEN
        NEW."whatsapp" := NEW."Telefono";
    ELSIF NEW."whatsapp" IS NOT NULL AND (OLD."whatsapp" IS NULL OR NEW."whatsapp" <> OLD."whatsapp") THEN
        NEW."Telefono" := NEW."whatsapp";
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_sync_users_fields
BEFORE INSERT OR UPDATE ON public.users
FOR EACH ROW
EXECUTE FUNCTION sync_users_fields();

-- Trigger para public."Personal"
CREATE OR REPLACE FUNCTION sync_personal_fields()
RETURNS TRIGGER AS $$
BEGIN
    -- NombrePersonal <-> nombre
    IF NEW."NombrePersonal" IS NOT NULL AND (OLD."NombrePersonal" IS NULL OR NEW."NombrePersonal" <> OLD."NombrePersonal") THEN
        NEW."nombre" := NEW."NombrePersonal";
    ELSIF NEW."nombre" IS NOT NULL AND (OLD."nombre" IS NULL OR NEW."nombre" <> OLD."nombre") THEN
        NEW."NombrePersonal" := NEW."nombre";
    END IF;

    -- FotoEmpleado <-> foto_perfil
    IF NEW."FotoEmpleado" IS NOT NULL AND (OLD."FotoEmpleado" IS NULL OR NEW."FotoEmpleado" <> OLD."FotoEmpleado") THEN
        NEW."foto_perfil" := NEW."FotoEmpleado";
    ELSIF NEW."foto_perfil" IS NOT NULL AND (OLD."foto_perfil" IS NULL OR NEW."foto_perfil" <> OLD."foto_perfil") THEN
        NEW."FotoEmpleado" := NEW."foto_perfil";
    END IF;

    -- WhatsApp-Numero <-> telefono
    IF NEW."WhatsApp-Numero" IS NOT NULL AND (OLD."WhatsApp-Numero" IS NULL OR NEW."WhatsApp-Numero" <> OLD."WhatsApp-Numero") THEN
        NEW."telefono" := NEW."WhatsApp-Numero";
    ELSIF NEW."telefono" IS NOT NULL AND (OLD."telefono" IS NULL OR NEW."telefono" <> OLD."telefono") THEN
        NEW."WhatsApp-Numero" := NEW."telefono";
    END IF;

    -- Sucursal <-> sucursal
    IF NEW."Sucursal" IS NOT NULL AND (OLD."Sucursal" IS NULL OR NEW."Sucursal" <> OLD."Sucursal") THEN
        NEW."sucursal" := NEW."Sucursal";
    ELSIF NEW."sucursal" IS NOT NULL AND (OLD."sucursal" IS NULL OR NEW."sucursal" <> OLD."sucursal") THEN
        NEW."Sucursal" := NEW."sucursal";
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_sync_personal_fields
BEFORE INSERT OR UPDATE ON public."Personal"
FOR EACH ROW
EXECUTE FUNCTION sync_personal_fields();

-- Trigger para public."Productos"
CREATE OR REPLACE FUNCTION sync_productos_fields()
RETURNS TRIGGER AS $$
BEGIN
    -- NombreProducto <-> nombre
    IF NEW."NombreProducto" IS NOT NULL AND (OLD."NombreProducto" IS NULL OR NEW."NombreProducto" <> OLD."NombreProducto") THEN
        NEW."nombre" := NEW."NombreProducto";
    ELSIF NEW."nombre" IS NOT NULL AND (OLD."nombre" IS NULL OR NEW."nombre" <> OLD."nombre") THEN
        NEW."NombreProducto" := NEW."nombre";
    END IF;

    -- DescripciónProducto <-> descripcion
    IF NEW."DescripciónProducto" IS NOT NULL AND (OLD."DescripciónProducto" IS NULL OR NEW."DescripciónProducto" <> OLD."DescripciónProducto") THEN
        NEW."descripcion" := NEW."DescripciónProducto";
    ELSIF NEW."descripcion" IS NOT NULL AND (OLD."descripcion" IS NULL OR NEW."descripcion" <> OLD."descripcion") THEN
        NEW."DescripciónProducto" := NEW."descripcion";
    END IF;

    -- montoProducto <-> precio
    IF NEW."montoProducto" IS NOT NULL AND (OLD."montoProducto" IS NULL OR NEW."montoProducto" <> OLD."montoProducto") THEN
        NEW."precio" := NEW."montoProducto";
    ELSIF NEW."precio" IS NOT NULL AND (OLD."precio" IS NULL OR NEW."precio" <> OLD."precio") THEN
        NEW."montoProducto" := NEW."precio";
    END IF;

    -- cantidadInventario <-> stock
    IF NEW."cantidadInventario" IS NOT NULL AND (OLD."cantidadInventario" IS NULL OR NEW."cantidadInventario" <> OLD."cantidadInventario") THEN
        NEW."stock" := NEW."cantidadInventario";
    ELSIF NEW."stock" IS NOT NULL AND (OLD."stock" IS NULL OR NEW."stock" <> OLD."stock") THEN
        NEW."cantidadInventario" := NEW."stock";
    END IF;

    -- ImagenProducto <-> imagen_url
    IF NEW."ImagenProducto" IS NOT NULL AND (OLD."ImagenProducto" IS NULL OR NEW."ImagenProducto" <> OLD."ImagenProducto") THEN
        NEW."imagen_url" := NEW."ImagenProducto";
    ELSIF NEW."imagen_url" IS NOT NULL AND (OLD."imagen_url" IS NULL OR NEW."imagen_url" <> OLD."imagen_url") THEN
        NEW."ImagenProducto" := NEW."imagen_url";
    END IF;

    -- isDisponibleVenta <-> disponible_venta
    IF NEW."isDisponibleVenta" IS NOT NULL AND (OLD."isDisponibleVenta" IS NULL OR NEW."isDisponibleVenta" <> OLD."isDisponibleVenta") THEN
        NEW."disponible_venta" := NEW."isDisponibleVenta";
    ELSIF NEW."disponible_venta" IS NOT NULL AND (OLD."disponible_venta" IS NULL OR NEW."disponible_venta" <> OLD."disponible_venta") THEN
        NEW."isDisponibleVenta" := NEW."disponible_venta";
    END IF;

    -- Categoria <-> categoria
    IF NEW."Categoria" IS NOT NULL AND (OLD."Categoria" IS NULL OR NEW."Categoria" <> OLD."Categoria") THEN
        NEW."categoria" := NEW."Categoria";
    ELSIF NEW."categoria" IS NOT NULL AND (OLD."categoria" IS NULL OR NEW."categoria" <> OLD."categoria") THEN
        NEW."Categoria" := NEW."categoria";
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_sync_productos_fields
BEFORE INSERT OR UPDATE ON public."Productos"
FOR EACH ROW
EXECUTE FUNCTION sync_productos_fields();


-- ============================================================================
-- 4. CREACIÓN DEL PRIMER USUARIO SUPER ADMINISTRADOR (SEMILLA)
-- ============================================================================

-- Asegurar que pgcrypto está activado para el cifrado de contraseñas
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 1. Insertar el usuario en auth.users
INSERT INTO auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    recovery_sent_at,
    last_sign_in_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at,
    confirmation_token,
    email_change,
    email_change_token_new,
    recovery_token
)
SELECT
    '00000000-0000-0000-0000-000000000000',
    'd3b07384-d113-4c9f-a5bf-86926f28d8b4',
    'authenticated',
    'authenticated',
    'vidalcavazos@gmail.com',
    crypt('vidal2026', gen_salt('bf')),
    now(),
    null,
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"nombre":"Vidal Cavazos"}'::jsonb,
    now(),
    now(),
    '',
    '',
    '',
    ''
WHERE NOT EXISTS (
    SELECT 1 FROM auth.users WHERE email = 'vidalcavazos@gmail.com'
);

-- 2. Insertar la identidad del usuario en auth.identities (utilizando un bloque PL/pgSQL dinámico para soportar esquemas antiguos y nuevos de Supabase)
DO $$
DECLARE
    has_provider_id boolean;
BEGIN
    SELECT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_schema = 'auth' 
          AND table_name = 'identities' 
          AND column_name = 'provider_id'
    ) INTO has_provider_id;

    IF NOT EXISTS (SELECT 1 FROM auth.identities WHERE user_id = 'd3b07384-d113-4c9f-a5bf-86926f28d8b4') THEN
        IF has_provider_id THEN
            -- Esquema nuevo: requiere provider_id (pero email es una columna generada, por lo que se omite)
            EXECUTE 'INSERT INTO auth.identities (
                id,
                user_id,
                identity_data,
                provider,
                provider_id,
                last_sign_in_at,
                created_at,
                updated_at
            ) VALUES (
                ''d3b07384-d113-4c9f-a5bf-86926f28d8b4'',
                ''d3b07384-d113-4c9f-a5bf-86926f28d8b4'',
                ''{"sub":"d3b07384-d113-4c9f-a5bf-86926f28d8b4","email":"vidalcavazos@gmail.com"}''::jsonb,
                ''email'',
                ''d3b07384-d113-4c9f-a5bf-86926f28d8b4'',
                now(),
                now(),
                now()
            )';
        ELSE
            -- Esquema antiguo: sin provider_id ni email
            EXECUTE 'INSERT INTO auth.identities (
                id,
                user_id,
                identity_data,
                provider,
                last_sign_in_at,
                created_at,
                updated_at
            ) VALUES (
                ''d3b07384-d113-4c9f-a5bf-86926f28d8b4'',
                ''d3b07384-d113-4c9f-a5bf-86926f28d8b4'',
                ''{"sub":"d3b07384-d113-4c9f-a5bf-86926f28d8b4","email":"vidalcavazos@gmail.com"}''::jsonb,
                ''email'',
                now(),
                now(),
                now()
            )';
        END IF;
    END IF;
END $$;

-- 3. Insertar el perfil del super administrador en public.users
INSERT INTO public.users (
    "IDUser",
    "nombre",
    "NombreCompleto",
    "correo",
    "Telefono",
    "whatsapp",
    "isPersonal",
    "isAdmin",
    "isGestor",
    "isRecepcion"
)
SELECT
    'd3b07384-d113-4c9f-a5bf-86926f28d8b4',
    'Vidal Cavazos',
    'Vidal Cavazos',
    'vidalcavazos@gmail.com',
    '1234567890',
    '1234567890',
    false,
    true, -- SuperAdmin como TRUE
    false,
    false
WHERE NOT EXISTS (
    SELECT 1 FROM public.users WHERE "IDUser" = 'd3b07384-d113-4c9f-a5bf-86926f28d8b4'
);

