#!/bin/bash

# Crear directorios principales
mkdir -p src/components/Dashboard src/components/VideoAnalysis src/components/DigitalAssistant src/components/Inventory src/components/Alerts src/components/Auth src/components/Layout
mkdir -p src/context src/hooks src/utils src/services src/pages src/styles
mkdir -p functions/videoAnalysis functions/faceRecognition functions/emotionDetection functions/inventoryControl functions/notifications

# Crear archivos de configuración de Firebase
cat > src/services/firebase.js << 'EOL'
import { initializeApp } from 'firebase/app';
import { getAuth, connectAuthEmulator } from 'firebase/auth';
import { getFirestore, connectFirestoreEmulator } from 'firebase/firestore';
import { getStorage, connectStorageEmulator } from 'firebase/storage';
import { getFunctions, connectFunctionsEmulator } from 'firebase/functions';

const firebaseConfig = {
  apiKey: "YOUR_API_KEY",
  authDomain: "silverguard-pro.firebaseapp.com",
  projectId: "silverguard-pro",
  storageBucket: "silverguard-pro.appspot.com",
  messagingSenderId: "YOUR_MESSAGING_SENDER_ID",
  appId: "YOUR_APP_ID",
  measurementId: "YOUR_MEASUREMENT_ID"
};

// Inicializar Firebase
const app = initializeApp(firebaseConfig);

// Inicializar servicios
const auth = getAuth(app);
const db = getFirestore(app);
const storage = getStorage(app);
const functions = getFunctions(app);

// Conectar con emuladores en desarrollo
if (process.env.NODE_ENV === 'development') {
  connectAuthEmulator(auth, 'http://localhost:9099');
  connectFirestoreEmulator(db, 'localhost', 8080);
  connectStorageEmulator(storage, 'localhost', 9199);
  connectFunctionsEmulator(functions, 'localhost', 5001);
}

export { app, auth, db, storage, functions };
EOL

# Crear contextos
cat > src/context/AuthContext.js << 'EOL'
import React, { createContext, useContext, useState, useEffect } from 'react';
import { 
  createUserWithEmailAndPassword,
  signInWithEmailAndPassword,
  signOut,
  onAuthStateChanged,
  updateProfile,
  sendPasswordResetEmail
} from 'firebase/auth';
import { doc, setDoc, getDoc } from 'firebase/firestore';
import { auth, db } from '../services/firebase';

const AuthContext = createContext();

export function useAuth() {
  return useContext(AuthContext);
}

export function AuthProvider({ children }) {
  const [currentUser, setCurrentUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const [userRole, setUserRole] = useState(null);

  async function signup(email, password, firstName, lastName) {
    try {
      const userCredential = await createUserWithEmailAndPassword(auth, email, password);
      await updateProfile(userCredential.user, {
        displayName: `${firstName} ${lastName}`
      });
      
      await setDoc(doc(db, 'users', userCredential.user.uid), {
        firstName,
        lastName,
        email,
        role: 'user',
        createdAt: new Date().toISOString()
      });
      
      return userCredential.user;
    } catch (error) {
      throw error;
    }
  }

  async function login(email, password) {
    return signInWithEmailAndPassword(auth, email, password);
  }

  function logout() {
    return signOut(auth);
  }

  function resetPassword(email) {
    return sendPasswordResetEmail(auth, email);
  }

  async function getUserData(userId) {
    const userDoc = await getDoc(doc(db, 'users', userId));
    if (userDoc.exists()) {
      return userDoc.data();
    }
    return null;
  }

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, async (user) => {
      setCurrentUser(user);
      if (user) {
        const userData = await getUserData(user.uid);
        setUserRole(userData?.role || 'user');
      } else {
        setUserRole(null);
      }
      setLoading(false);
    });

    return unsubscribe;
  }, []);

  const value = {
    currentUser,
    userRole,
    signup,
    login,
    logout,
    resetPassword,
    getUserData,
    loading
  };

  return (
    <AuthContext.Provider value={value}>
      {children}
    </AuthContext.Provider>
  );
}
EOL

cat > src/context/ThemeContext.js << 'EOL'
import React, { createContext, useContext, useState, useEffect } from 'react';

const ThemeContext = createContext();

export function useTheme() {
  return useContext(ThemeContext);
}

export function ThemeProvider({ children }) {
  const [theme, setTheme] = useState(
    localStorage.getItem('theme') || 'light'
  );

  useEffect(() => {
    localStorage.setItem('theme', theme);
  }, [theme]);

  function toggleTheme() {
    setTheme(prevTheme => prevTheme === 'light' ? 'dark' : 'light');
  }

  const value = {
    theme,
    toggleTheme
  };

  return (
    <ThemeContext.Provider value={value}>
      {children}
    </ThemeContext.Provider>
  );
}
EOL

cat > src/context/AlertContext.js << 'EOL'
import React, { createContext, useContext, useState } from 'react';
import { collection, addDoc, query, where, orderBy, onSnapshot, updateDoc, doc } from 'firebase/firestore';
import { useAuth } from './AuthContext';
import { db } from '../services/firebase';

const AlertContext = createContext();

export function useAlerts() {
  return useContext(AlertContext);
}

export function AlertProvider({ children }) {
  const [alerts, setAlerts] = useState([]);
  const [loading, setLoading] = useState(true);
  const { currentUser } = useAuth();

  // Obtener alertas desde Firestore
  React.useEffect(() => {
    if (!currentUser) {
      setAlerts([]);
      setLoading(false);
      return;
    }

    const q = query(
      collection(db, 'alerts'),
      orderBy('timestamp', 'desc')
    );

    const unsubscribe = onSnapshot(q, (querySnapshot) => {
      const alertsList = querySnapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      }));
      setAlerts(alertsList);
      setLoading(false);
    });

    return unsubscribe;
  }, [currentUser]);

  // Crear una nueva alerta
  async function createAlert(alertData) {
    try {
      const newAlert = {
        ...alertData,
        timestamp: new Date().toISOString(),
        status: 'active',
        createdBy: currentUser.uid
      };
      
      const docRef = await addDoc(collection(db, 'alerts'), newAlert);
      return docRef.id;
    } catch (error) {
      console.error('Error adding alert: ', error);
      throw error;
    }
  }

  // Marcar alerta como resuelta
  async function resolveAlert(alertId, resolution) {
    try {
      await updateDoc(doc(db, 'alerts', alertId), {
        status: 'resolved',
        resolvedBy: currentUser.uid,
        resolvedAt: new Date().toISOString(),
        resolution
      });
    } catch (error) {
      console.error('Error resolving alert: ', error);
      throw error;
    }
  }

  // Obtener alertas sin leer
  function getUnreadAlerts() {
    return alerts.filter(alert => alert.status === 'active' && !alert.read);
  }

  // Marcar alerta como leída
  async function markAsRead(alertId) {
    try {
      await updateDoc(doc(db, 'alerts', alertId), {
        read: true,
        readAt: new Date().toISOString()
      });
    } catch (error) {
      console.error('Error marking alert as read: ', error);
      throw error;
    }
  }

  const value = {
    alerts,
    loading,
    createAlert,
    resolveAlert,
    getUnreadAlerts,
    markAsRead
  };

  return (
    <AlertContext.Provider value={value}>
      {children}
    </AlertContext.Provider>
  );
}
EOL

# Crear App.js
cat > src/App.js << 'EOL'
import React, { useEffect } from 'react';
import { Routes, Route, Navigate } from 'react-router-dom';
import { useAuth } from './context/AuthContext';
import { CssBaseline, CircularProgress, Box } from '@mui/material';
import { useTheme } from './context/ThemeContext';

// Componentes de Layout
import MainLayout from './components/Layout/MainLayout';

// Páginas
import Dashboard from './pages/Dashboard';
import Login from './pages/Login';
import VideoAnalysis from './pages/VideoAnalysis';
import FaceRecognition from './pages/FaceRecognition';
import EmotionDetection from './pages/EmotionDetection';
import InventoryControl from './pages/InventoryControl';
import AlertsManagement from './pages/AlertsManagement';
import Settings from './pages/Settings';
import NotFound from './pages/NotFound';
import Profile from './pages/Profile';
import DigitalAssistant from './pages/DigitalAssistant';
import Reports from './pages/Reports';

// Rutas protegidas
const ProtectedRoute = ({ children }) => {
  const { currentUser, loading } = useAuth();
  
  if (loading) {
    return (
      <Box sx={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: '100vh' }}>
        <CircularProgress />
      </Box>
    );
  }
  
  if (!currentUser) {
    return <Navigate to="/login" />;
  }
  
  return children;
};

function App() {
  const { theme } = useTheme();
  const { currentUser, loading } = useAuth();
  
  useEffect(() => {
    document.body.className = theme;
  }, [theme]);
  
  if (loading) {
    return (
      <Box sx={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: '100vh' }}>
        <CircularProgress />
      </Box>
    );
  }
  
  return (
    <>
      <CssBaseline />
      <Routes>
        <Route path="/login" element={currentUser ? <Navigate to="/" /> : <Login />} />
        
        <Route path="/" element={
          <ProtectedRoute>
            <MainLayout />
          </ProtectedRoute>
        }>
          <Route index element={<Dashboard />} />
          <Route path="video-analysis" element={<VideoAnalysis />} />
          <Route path="face-recognition" element={<FaceRecognition />} />
          <Route path="emotion-detection" element={<EmotionDetection />} />
          <Route path="inventory" element={<InventoryControl />} />
          <Route path="alerts" element={<AlertsManagement />} />
          <Route path="digital-assistant" element={<DigitalAssistant />} />
          <Route path="reports" element={<Reports />} />
          <Route path="settings" element={<Settings />} />
          <Route path="profile" element={<Profile />} />
        </Route>
        
        <Route path="*" element={<NotFound />} />
      </Routes>
    </>
  );
}

export default App;
EOL

# Crear archivos de configuración de Firebase
cat > firestore.rules << 'EOL'
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Autenticación requerida para todas las operaciones
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
    
    // Reglas para usuarios
    match /users/{userId} {
      allow read: if request.auth != null && request.auth.uid == userId;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Reglas para inventario
    match /inventory/{itemId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.token.admin == true;
    }
    
    // Reglas para alertas
    match /alerts/{alertId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
    
    // Reglas para eventos
    match /events/{eventId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update, delete: if request.auth != null && request.auth.token.admin == true;
    }
  }
}
EOL

cat > storage.rules << 'EOL'
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /{allPaths=**} {
      allow read, write: if request.auth != null;
    }
    
    // Reglas para videos de seguridad
    match /security-videos/{videoId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
    
    // Reglas para imágenes de inventario
    match /inventory-images/{imageId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.token.admin == true;
    }
  }
}
EOL

# Crear componentes de Layout
cat > src/components/Layout/MainLayout.js << 'EOL'
import React, { useState } from 'react';
import { Outlet } from 'react-router-dom';
import { Box, CssBaseline, Drawer, AppBar, Toolbar, List, Typography, Divider, IconButton, Badge, Avatar } from '@mui/material';
import { Menu as MenuIcon, Notifications as NotificationsIcon, AccountCircle, Settings, Dashboard, Videocam, Face, EmojiEmotions, Inventory, NotificationsActive, Android } from '@mui/icons-material';
import { styled } from '@mui/material/styles';
import { useAuth } from '../../context/AuthContext';
import { useAlerts } from '../../context/AlertContext';
import { useTheme } from '../../context/ThemeContext';
import Sidebar from './Sidebar';
import UserMenu from './UserMenu';
import NotificationsMenu from './NotificationsMenu';

const drawerWidth = 240;

const Main = styled('main', { shouldForwardProp: (prop) => prop !== 'open' })(
  ({ theme, open }) => ({
    flexGrow: 1,
    padding: theme.spacing(3),
    transition: theme.transitions.create('margin', {
      easing: theme.transitions.easing.sharp,
      duration: theme.transitions.duration.leavingScreen,
    }),
    marginLeft: `-${drawerWidth}px`,
    ...(open && {
      transition: theme.transitions.create('margin', {
        easing: theme.transitions.easing.easeOut,
        duration: theme.transitions.duration.enteringScreen,
      }),
      marginLeft: 0,
    }),
  }),
);

const AppBarStyled = styled(AppBar, { shouldForwardProp: (prop) => prop !== 'open' })(
  ({ theme, open }) => ({
    transition: theme.transitions.create(['margin', 'width'], {
      easing: theme.transitions.easing.sharp,
      duration: theme.transitions.duration.leavingScreen,
    }),
    ...(open && {
      width: `calc(100% - ${drawerWidth}px)`,
      marginLeft: `${drawerWidth}px`,
      transition: theme.transitions.create(['margin', 'width'], {
        easing: theme.transitions.easing.easeOut,
        duration: theme.transitions.duration.enteringScreen,
      }),
    }),
  }),
);

const DrawerHeader = styled('div')(({ theme }) => ({
  display: 'flex',
  alignItems: 'center',
  padding: theme.spacing(0, 1),
  ...theme.mixins.toolbar,
  justifyContent: 'flex-end',
}));

function MainLayout() {
  const { currentUser, userRole } = useAuth();
  const { getUnreadAlerts } = useAlerts();
  const { theme, toggleTheme } = useTheme();
  
  const [open, setOpen] = useState(true);
  const [userMenuAnchorEl, setUserMenuAnchorEl] = useState(null);
  const [notificationsAnchorEl, setNotificationsAnchorEl] = useState(null);
  
  const unreadAlerts = getUnreadAlerts();
  
  const handleDrawerOpen = () => {
    setOpen(true);
  };

  const handleDrawerClose = () => {
    setOpen(false);
  };
  
  const handleUserMenuOpen = (event) => {
    setUserMenuAnchorEl(event.currentTarget);
  };
  
  const handleUserMenuClose = () => {
    setUserMenuAnchorEl(null);
  };
  
  const handleNotificationsOpen = (event) => {
    setNotificationsAnchorEl(event.currentTarget);
  };
  
  const handleNotificationsClose = () => {
    setNotificationsAnchorEl(null);
  };
  
  return (
    <Box sx={{ display: 'flex' }}>
      <CssBaseline />
      <AppBarStyled position="fixed" open={open}>
        <Toolbar>
          <IconButton
            color="inherit"
            aria-label="open drawer"
            onClick={handleDrawerOpen}
            edge="start"
            sx={{ mr: 2, ...(open && { display: 'none' }) }}
          >
            <MenuIcon />
          </IconButton>
          <Typography variant="h6" noWrap component="div" sx={{ flexGrow: 1 }}>
            SilverGuard Pro 2.0
          </Typography>
          
          <IconButton color="inherit" onClick={handleNotificationsOpen}>
            <Badge badgeContent={unreadAlerts.length} color="error">
              <NotificationsIcon />
            </Badge>
          </IconButton>
          
          <IconButton
            edge="end"
            aria-label="account of current user"
            aria-haspopup="true"
            onClick={handleUserMenuOpen}
            color="inherit"
          >
            {currentUser?.photoURL ? (
              <Avatar src={currentUser.photoURL} alt={currentUser.displayName} />
            ) : (
              <AccountCircle />
            )}
          </IconButton>
        </Toolbar>
      </AppBarStyled>
      
      <Drawer
        sx={{
          width: drawerWidth,
          flexShrink: 0,
          '& .MuiDrawer-paper': {
            width: drawerWidth,
            boxSizing: 'border-box',
          },
        }}
        variant="persistent"
        anchor="left"
        open={open}
      >
        <DrawerHeader>
          <Typography variant="h6" noWrap component="div" sx={{ flexGrow: 1, ml: 2 }}>
            Menú Principal
          </Typography>
          <IconButton onClick={handleDrawerClose}>
            <MenuIcon />
          </IconButton>
        </DrawerHeader>
        <Divider />
        <Sidebar onClose={handleDrawerClose} userRole={userRole} />
      </Drawer>
      
      <Main open={open}>
        <DrawerHeader />
        <Outlet />
      </Main>
      
      <UserMenu
        anchorEl={userMenuAnchorEl}
        open={Boolean(userMenuAnchorEl)}
        onClose={handleUserMenuClose}
        currentUser={currentUser}
        theme={theme}
        toggleTheme={toggleTheme}
      />
      
      <NotificationsMenu
        anchorEl={notificationsAnchorEl}
        open={Boolean(notificationsAnchorEl)}
        onClose={handleNotificationsClose}
        alerts={unreadAlerts}
      />
    </Box>
  );
}

export default MainLayout;
EOL

cat > src/components/Layout/Sidebar.js << 'EOL'
import React from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import { List, ListItem, ListItemButton, ListItemIcon, ListItemText, Divider } from '@mui/material';
import {
  Dashboard,