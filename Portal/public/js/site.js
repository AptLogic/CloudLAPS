// JavaScript for CloudLAPS Portal

/**
 * Submit the search form and display a busy indicator while the search is being processed.
 */
function submitSearchForm() {
  const loadingElement = document.getElementById("loading");
  const submitButton = document.getElementById("Search");

  if (loadingElement) {
    loadingElement.style.display = "block";
  }

  if (submitButton) {
    submitButton.setAttribute("disabled", "disabled");
    submitButton.textContent = "Searching...";
  }

  document.getElementById("search-form").submit();
}

document.addEventListener("DOMContentLoaded", () => {
  const form = document.getElementById("search-form");
  if (!form) {
    return;
  }

  form.addEventListener("submit", (event) => {
    event.preventDefault();
    submitSearchForm();
  });
});
