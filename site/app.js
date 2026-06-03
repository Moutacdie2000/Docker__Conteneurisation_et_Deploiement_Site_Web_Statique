/* =========================================================================
 * Docker Static Site — Script de la landing page
 * JavaScript natif (sans framework). Trois petites améliorations
 * progressives : menu mobile accessible, bouton « copier » du snippet
 * et mise à jour de l'année dans le pied de page.
 * ========================================================================= */

(function () {
  "use strict";

  /**
   * Initialise le menu de navigation mobile (bouton hamburger).
   * Gère l'attribut aria-expanded, la fermeture au clic sur un lien,
   * au clic à l'extérieur et à la touche Échap.
   */
  function initMobileNav() {
    var toggle = document.querySelector(".nav__toggle");
    var menu = document.getElementById("nav-menu");

    if (!toggle || !menu) {
      return;
    }

    function setOpen(isOpen) {
      toggle.setAttribute("aria-expanded", String(isOpen));
      menu.classList.toggle("is-open", isOpen);
      toggle.setAttribute(
        "aria-label",
        isOpen ? "Fermer le menu de navigation" : "Ouvrir le menu de navigation"
      );
    }

    toggle.addEventListener("click", function () {
      var isOpen = toggle.getAttribute("aria-expanded") === "true";
      setOpen(!isOpen);
    });

    // Fermeture lorsqu'on clique sur un lien du menu.
    menu.addEventListener("click", function (event) {
      if (event.target.closest("a")) {
        setOpen(false);
      }
    });

    // Fermeture avec la touche Échap.
    document.addEventListener("keydown", function (event) {
      if (event.key === "Escape") {
        setOpen(false);
      }
    });

    // Fermeture au clic en dehors de la barre de navigation.
    document.addEventListener("click", function (event) {
      if (!event.target.closest(".nav")) {
        setOpen(false);
      }
    });
  }

  /**
   * Active le bouton « Copier » de la carte de code.
   * Copie le contenu textuel de la cible dans le presse-papiers
   * et fournit un retour visuel temporaire.
   */
  function initCopyButton() {
    var button = document.querySelector(".code-card__copy");

    if (!button) {
      return;
    }

    var targetId = button.getAttribute("data-copy-target");
    var target = targetId ? document.getElementById(targetId) : null;
    var defaultLabel = button.textContent;

    if (!target) {
      return;
    }

    function showFeedback(message) {
      button.textContent = message;
      button.classList.add("is-copied");
      window.setTimeout(function () {
        button.textContent = defaultLabel;
        button.classList.remove("is-copied");
      }, 1800);
    }

    /** Solution de repli si l'API Clipboard n'est pas disponible. */
    function fallbackCopy(text) {
      var textarea = document.createElement("textarea");
      textarea.value = text;
      textarea.setAttribute("readonly", "");
      textarea.style.position = "absolute";
      textarea.style.left = "-9999px";
      document.body.appendChild(textarea);
      textarea.select();

      var succeeded = false;
      try {
        succeeded = document.execCommand("copy");
      } catch (error) {
        succeeded = false;
      }

      document.body.removeChild(textarea);
      return succeeded;
    }

    button.addEventListener("click", function () {
      var text = target.textContent || "";

      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(text).then(
          function () {
            showFeedback("Copié !");
          },
          function () {
            showFeedback(fallbackCopy(text) ? "Copié !" : "Échec");
          }
        );
      } else {
        showFeedback(fallbackCopy(text) ? "Copié !" : "Échec");
      }
    });
  }

  /** Met à jour l'année affichée dans le pied de page. */
  function initYear() {
    var yearNode = document.getElementById("year");
    if (yearNode) {
      yearNode.textContent = String(new Date().getFullYear());
    }
  }

  function init() {
    initMobileNav();
    initCopyButton();
    initYear();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
