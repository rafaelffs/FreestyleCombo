import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import { Layout } from '@/components/layout/Layout'
import { ProtectedRoute } from '@/components/layout/ProtectedRoute'
import { AdminRoute } from '@/components/layout/AdminRoute'
import { LoginPage } from '@/features/auth/LoginPage'
import { RegisterPage } from '@/features/auth/RegisterPage'
import { CombosPage } from '@/features/combos/CombosPage'
import { CreateComboPage } from '@/features/combos/CreateComboPage'
import { ComboDetailPage } from '@/features/combos/ComboDetailPage'
import { PreferencesPage } from '@/features/preferences/PreferencesPage'
import { TricksPage } from '@/features/tricks/TricksPage'
import { AdminSubmissionsPage } from '@/features/tricks/AdminSubmissionsPage'
import { AdminComboReviewsPage } from '@/features/combos/AdminComboReviewsPage'

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route element={<Layout />}>
          {/* Public */}
          <Route path="/login" element={<LoginPage />} />
          <Route path="/register" element={<RegisterPage />} />
          <Route path="/combos" element={<CombosPage />} />
          <Route path="/combos/:id" element={<ComboDetailPage />} />
          <Route path="/tricks" element={<TricksPage />} />

          {/* Protected */}
          <Route element={<ProtectedRoute />}>
            <Route path="/combos/create" element={<CreateComboPage />} />
            <Route path="/preferences" element={<PreferencesPage />} />
          </Route>

          {/* Admin only */}
          <Route element={<AdminRoute />}>
            <Route path="/admin/submissions" element={<AdminSubmissionsPage />} />
            <Route path="/admin/combo-reviews" element={<AdminComboReviewsPage />} />
          </Route>

          {/* Redirects for old routes */}
          <Route path="/combos/public" element={<Navigate to="/combos" replace />} />
          <Route path="/combos/mine" element={<Navigate to="/combos" replace />} />
          <Route path="/generate" element={<Navigate to="/combos/create" replace />} />
          <Route path="/combos/build" element={<Navigate to="/combos/create" replace />} />
          <Route path="/tricks/submit" element={<Navigate to="/tricks" replace />} />

          <Route path="/" element={<Navigate to="/combos" replace />} />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Route>
      </Routes>
    </BrowserRouter>
  )
}
