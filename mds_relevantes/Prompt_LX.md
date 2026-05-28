# Estructura General de la Aplicación

La aplicación tendrá una navegación principal compuesta por 5 secciones dentro del `AppBar` o `BottomNavigationBar`.

|Sección|Descripción|
|---|---|
|Inicio|Feed principal de la aplicación|
|Chats|Lista y sistema de conversaciones|
|Crear|Publicar una nueva card|
|Comunidad|Sección de comunidades y categorías|
|Perfil|Perfil del usuario|

---

# 1. Screen de Inicio

Esta pantalla funcionará como el feed principal de la aplicación.

## Elementos principales

### Carrusel horizontal de cards

En la parte superior se mostrará un carrusel horizontal de cards, similar al comportamiento visual de la sección de historias o amigos sugeridos de Facebook, pero utilizando cards personalizadas.

Cada card debe incluir:

- Imagen principal
    
- Nombre o título
    
- Información breve
    
- Diseño moderno y limpio
    

### Feed de publicaciones

Debajo del carrusel se mostrará un feed vertical de publicaciones relacionadas con aprendizaje de idiomas.

El diseño debe sentirse moderno, minimalista y enfocado en buena experiencia de usuario.

---

# 2. Screen de Chats

La lógica base del sistema de chat deberá tomar como referencia el código ubicado en:

`resources/lib_referencia`

Dentro de esa carpeta existe una demo funcional que representa el comportamiento esperado del chat.

## Requisitos

- Replicar la lógica principal del demo
    
- Mantener una arquitectura limpia y escalable
    
- Preparar la estructura para futura integración con Supabase
    
- Utilizar temporalmente mock data
    
- Diseñar pensando en futuras funcionalidades
    

Por el momento no es necesario implementar backend real.

---

# 3. Sección Crear Nueva Card

Al presionar el ícono `+`, el usuario podrá crear una nueva publicación tipo card.

## Flujo esperado

1. Abrir galería del dispositivo
    
2. Seleccionar imagen
    
3. Mostrar preview de la imagen
    
4. Completar formulario básico
    

## Campos del formulario

- Título
    
- Descripción
    
- Idioma
    
- Categoría
    
- Nivel
    
- Tags opcionales
    

El diseño debe ser simple, rápido y cómodo para publicar.

---

# 4. Screen de Comunidad

Esta sección será temporal y funcionará como explorador de comunidades.

## Requisitos

Mostrar categorías clickeables como:

- English for Architects
    
- English for Engineers
    
- English for Doctors
    
- Business English
    
- English for Programming
    

Las categorías pueden cambiar en el futuro, por lo que la estructura debe ser flexible y fácilmente escalable.

---

# 5. Screen de Perfil

La pantalla de perfil debe inspirarse en el diseño de perfil de Instagram.

## Elementos del perfil

- Foto de perfil
    
- Nombre
    
- Biografía
    
- Seguidores
    
- Seguidos
    
- Estadísticas básicas
    

## Grid de contenido

En lugar de publicaciones tradicionales, el grid mostrará las cards utilizadas dentro de la aplicación.

### Requisitos del grid

- Grid de 3 columnas
    
- Scroll fluido
    
- Diseño limpio y responsive
    
- Cards reutilizables
    

Aplicar buenas prácticas modernas de UI/UX y arquitectura Flutter.
