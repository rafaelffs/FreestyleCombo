import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import { Layout } from '@/components/layout/Layout'
import { ProtectedRoute } from '@/components/layout/ProtectedRoute'
import { LoginPage } from '@/features/auth/LoginPage'
import { RegisterPage } from '@/features/auth/RegisterPage'
import { GenerateComboPage } from '@/features/combos/GenerateComboPage'
import { PublicCombosPage } from '@/features/combos/PublicCombosPage'
import { MyCombosPage } from '@/features/combos/MyCombosPage'
import { ComboDetailPage } from '@/features/combos/ComboDetailPage'
import { PreferencesPage } from '@/features/preferences/PreferencesPage'

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route element={<Layout />}>
          {/* Public */}
          <Route path="/login" element={<LoginPage />} />
          <Route path="/register" element={<RegisterPage />} />
          <Route path="/combos/public" element={<PublicCombosPage />} />
          <Route path="/combos/:id" element={<ComboDetailPage />} />

          {/* Protected */}
          <Route element={<ProtectedRoute />}>
            <Route path="/generate" element={<GenerateComboPage />} />
            <Route path="/combos/mine" element={<MyCombosPage />} />
            <Route path="/preferences" element={<PreferencesPage />} />
          </Route>

          <Route path="/" element={<Navigate to="/generate" replace />} />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Route>
      </Routes>
    </BrowserRouter>
  )
}
