import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import { Layout } from '@/components/layout/Layout'
import { ProtectedRoute } from '@/components/layout/ProtectedRoute'
import { AdminRoute } from '@/components/layout/AdminRoute'
import { LandingPage } from '@/features/home/LandingPage'
import { LoginPage } from '@/features/auth/LoginPage'
import { RegisterPage } from '@/features/auth/RegisterPage'
import { CombosPage } from '@/features/combos/CombosPage'
import { CreateComboPage } from '@/features/combos/CreateComboPage'
import { ComboDetailPage } from '@/features/combos/ComboDetailPage'
import { PreferencesPage } from '@/features/preferences/PreferencesPage'
import { TricksPage } from '@/features/tricks/TricksPage'
import { AnimationPage } from '@/features/animation/AnimationPage'
import { AdminSubmissionsPage } from '@/features/tricks/AdminSubmissionsPage'
import { AccountPage } from '@/features/account/AccountPage'
import { UserProfilePage } from '@/features/users/UserProfilePage'
import { AdminUsersPage } from '@/features/admin/AdminUsersPage'

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
          <Route path="/animation" element={<AnimationPage />} />
          <Route path="/users/:id" element={<UserProfilePage />} />
          <Route path="/combos/create" element={<CreateComboPage />} />

          {/* Protected */}
          <Route element={<ProtectedRoute />}>
            <Route path="/preferences" element={<PreferencesPage />} />
            <Route path="/account" element={<AccountPage />} />
          </Route>

          {/* Admin only */}
          <Route element={<AdminRoute />}>
            <Route path="/admin/approvals" element={<AdminSubmissionsPage />} />
            <Route path="/admin/users" element={<AdminUsersPage />} />
          </Route>

          {/* Redirects for old routes */}
          <Route path="/combos/public" element={<Navigate to="/combos" replace />} />
          <Route path="/combos/mine" element={<Navigate to="/combos" replace />} />
          <Route path="/generate" element={<Navigate to="/combos/create" replace />} />
          <Route path="/combos/build" element={<Navigate to="/combos/create" replace />} />
          <Route path="/tricks/submit" element={<Navigate to="/tricks" replace />} />
          <Route path="/admin/submissions" element={<Navigate to="/admin/approvals" replace />} />
          <Route path="/admin/combo-reviews" element={<Navigate to="/admin/approvals" replace />} />

          <Route path="/" element={<LandingPage />} />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Route>
      </Routes>
    </BrowserRouter>
  )
}
