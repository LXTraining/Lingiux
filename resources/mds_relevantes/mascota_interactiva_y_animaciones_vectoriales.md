# Mascota Interactiva y Animaciones Vectoriales (Guía de Diseño e Implementación)

Integrar una mascota animada interactiva (como la lechuza **Duo** de Duolingo) le da una personalidad e identidad brutales a la aplicación.

Los profesionales **jamás** usan videos (MP4) o imágenes GIF para esto, ya que harían que la app pesara cientos de megabytes, se vería pixelado y consumiría toda la batería del celular.

Aquí te explico detalladamente la tecnología secreta que usan los profesionales y cómo puedes dar vida a tus bocetos paso a paso en Flutter:

---

## 🎨 1. Las dos tecnologías que usan los Profesionales

Hoy en día, la industria del desarrollo de apps utiliza principalmente dos herramientas para animaciones vectoriales ligeras:

### Opción A: Rive (La recomendada por excelencia para Flutter)
**Rive (rive.app)** es la plataforma líder para crear animaciones vectoriales interactivas en tiempo real. Es lo que usan apps modernas y videojuegos.
*   **¿Cómo funciona?**
    1.  Tomas tus bocetos y los redibujas en vectores (usando Figma o el propio editor de Rive).
    2.  Le creas un "esqueleto" digital al personaje (huesos y articulaciones). A esto se le llama **Rigging**.
    3.  Creas las animaciones en Rive (parpadear, saludar, celebrar, ponerse triste).
    4.  Creas una **Máquina de Estados (State Machine)** dentro de Rive. Esto define las transiciones. Por ejemplo: si el usuario escribe su contraseña, la mascota se tapa los ojos. Si el usuario acierta, salta de alegría.
*   **La gran ventaja**: El archivo generado `.riv` pesa apenas **50 KB** (ultra-ligero) y es **interactivo**: reacciona en tiempo real a lo que hace el usuario en la app.

### Opción B: Lottie (De Airbnb)
**Lottie** toma animaciones creadas en Adobe After Effects y las exporta como un archivo de texto plano en formato **JSON**.
*   **¿Cómo funciona?** El diseñador crea la animación en After Effects, la exporta con un plugin llamado *Bodymovin* y el desarrollador la carga en la app como si fuera un JSON común.
*   **La ventaja**: Es genial para animaciones lineales simples (un logo animado al inicio o una mascota saludando estáticamente).
*   **La desventaja**: No tiene interactividad en tiempo real (no puede seguir el dedo del usuario ni reaccionar dinámicamente a lo que escribe).

---

## 🚀 2. ¿Cómo se implementa para guiar en el Onboarding?

Imagina que tienes un Onboarding de 3 pantallas utilizando un `PageView`. Así es como lo programamos en Flutter usando **Rive**:

### Paso 1: Agregar el paquete
Añadimos la librería nativa de Rive en `pubspec.yaml`:
```yaml
dependencies:
  rive: ^0.13.0
```

### Paso 2: Diseñar la Máquina de Estados (State Machine) en Rive
En la interfaz de Rive, creas una entrada de tipo número llamada `onboarding_page`.
*   Si `onboarding_page == 0` -> La mascota ejecuta la animación `saludar`.
*   Si `onboarding_page == 1` -> La mascota ejecuta la animación `pensar` (mirando hacia un formulario).
*   Si `onboarding_page == 2` -> La mascota ejecuta la animación `celebrar` (cuando el usuario crea su cuenta).

### Paso 3: Vincular el PageView con la Mascota en Flutter
En el código de tu pantalla de Onboarding, escuchamos el desplazamiento del `PageView` y le pasamos ese valor directamente a la máquina de estados de Rive:

```dart
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late PageController _pageController;
  SMINumber? _pageInput; // Entrada numérica para controlar la mascota

  @override
  void initState() {
    super.initState();
    _pageController = PageController()
      ..addListener(() {
        // A medida que el usuario desliza con el dedo,
        // le enviamos el offset decimal exacto de la página a la mascota
        if (_pageInput != null) {
          _pageInput!.value = _pageController.page ?? 0;
        }
      });
  }
  
  // En tu método build, colocas el widget de Rive arriba de tu PageView
  // RiveAnimation.asset('assets/mascota.riv', stateMachines: ['OnboardingMachine'])
}
```

*   **El efecto mágico**: Como el valor que le pasamos es decimal (ej. `0.5` cuando vas a la mitad del scroll), **la mascota girará la cabeza y el cuerpo de manera fluida y suave acompañando el movimiento de tu dedo** mientras cambias de pantalla. ¡Se siente sumamente orgánico y profesional!

---

## 🎨 3. ¿Cómo puedes empezar con tus bocetos?

1.  **Pasa tus bocetos a vectores**: Importa tus dibujos en **Figma** y trázalos usando curvas (pluma) para tener un archivo limpio en vectores.
2.  **Importa a Rive (Gratuito)**: Ve a [rive.app](https://rive.app/), crea una cuenta gratuita y sube tu diseño en formato SVG o Figma.
3.  **Añade Huesos (Bones)**: Rive tiene tutoriales muy rápidos de 5 minutos sobre cómo colocar "huesos" al personaje para mover sus brazos, cabeza y ojos sin deformar el dibujo.
4.  **Crea 3 o 4 animaciones clave**:
    *   `idle` (respiración pasiva de la mascota).
    *   `success` (celebración al acertar).
    *   `typing` (mirando hacia abajo cuando el usuario escribe).
5.  **Compila y añade a Lingiux**: Una vez tengas tu archivo `.riv`, lo metemos en los assets de Lingiux y yo me encargaré de escribir toda la lógica en Flutter para que cobre vida en tus pantallas.
