// Initialize Supabase
const supabaseUrl = 'https://ezkwxnruzpjjarpieoll.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImV6a3d4bnJ1enBqamFycGllb2xsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkzMzczNjcsImV4cCI6MjA5NDkxMzM2N30.F7Sqzrre1dovmtti51O1NMglp_nUamFPgvjl1r1zUfQ';
const supabase = window.supabase.createClient(supabaseUrl, supabaseKey);

// DOM Elements
const emailInput = document.getElementById('email');
const passwordInput = document.getElementById('password');
const loginBtn = document.getElementById('loginBtn');
const signupBtn = document.getElementById('signupBtn');
const errorBox = document.getElementById('errorBox');
const successBox = document.getElementById('successBox');

function showError(msg) {
  errorBox.textContent = msg;
  errorBox.classList.remove('hidden');
  successBox.classList.add('hidden');
}

function showSuccess(msg) {
  successBox.textContent = msg;
  successBox.classList.remove('hidden');
  errorBox.classList.add('hidden');
}

// Sign Up Logic
if(signupBtn) {
  signupBtn.addEventListener('click', async () => {
    const email = emailInput.value.trim();
    const password = passwordInput.value.trim();
    
    if(!email || !password) {
      showError("Please enter email and password");
      return;
    }

    signupBtn.disabled = true;
    signupBtn.innerHTML = "Creating...";

    const { data, error } = await supabase.auth.signUp({
      email: email,
      password: password,
      options: {
        data: { full_name: 'New User' } // triggers handle_new_user
      }
    });

    if (error) {
      showError(error.message);
    } else {
      showSuccess("Account created successfully! You can now Sign In.");
    }
    
    signupBtn.disabled = false;
    signupBtn.innerHTML = "Create Account";
  });
}

// Login Logic
if(loginBtn) {
  loginBtn.addEventListener('click', async () => {
    const email = emailInput.value.trim();
    const password = passwordInput.value.trim();
    
    if(!email || !password) {
      showError("Please enter email and password");
      return;
    }

    loginBtn.disabled = true;
    loginBtn.innerHTML = "Signing in...";

    const { data, error } = await supabase.auth.signInWithPassword({
      email: email,
      password: password,
    });

    if (error) {
      showError(error.message);
      loginBtn.disabled = false;
      loginBtn.innerHTML = "Sign In";
    } else {
      // Redirect to plan-journey upon successful login
      window.location.href = "plan-journey.html";
    }
  });
}

// Check if already logged in on other pages
async function checkAuth() {
  const { data: { session } } = await supabase.auth.getSession();
  if (!session && !window.location.href.includes('login.html') && !window.location.href.includes('index.html')) {
    window.location.href = "login.html";
  }
}
