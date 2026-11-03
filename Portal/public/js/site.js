// JavaScript for CloudLAPS Portal

function showLoadingIndicator() {
  const loadingElement = document.getElementById("loading");

  if (loadingElement) {
    loadingElement.style.display = "block";
  }
}

/**
 * Submit the search form and display a busy indicator while the search is being processed.
 */
function submitSearchForm() {
  const submitButton = document.getElementById("Search");

  showLoadingIndicator();

  if (submitButton) {
    submitButton.setAttribute("disabled", "disabled");
    submitButton.textContent = "Searching...";
  }

  document.getElementById("search-form").submit();
}

function loadSecretVersion(selectElement) {
  if (!selectElement.value) {
    return;
  }

  showLoadingIndicator();
  selectElement.disabled = true;
  window.location.href = selectElement.value;
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
