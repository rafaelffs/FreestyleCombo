export { default, extractError } from './client'
export type { PagedResult } from './client'

export { authApi } from './auth'
export type { AuthResponse } from './auth'

export {
  combosApi,
  ratingsApi,
} from './combos'
export type {
  ComboDto,
  ComboTrickDto,
  GenerateComboOverrides,
  BuildComboTrickItem,
  PreviewTrickItem,
  PreviewComboResponse,
  RatingDto,
  PublicCombosParams,
  MineCombosParams,
} from './combos'

export { tricksApi, trickSubmissionsApi } from './tricks'
export type { TrickDto, TrickSubmissionDto, SubmitTrickRequest } from './tricks'

export { preferencesApi } from './preferences'
export type { UserPreference, PreferencePayload } from './preferences'

export { accountApi, adminApi } from './account'
export type { ProfileDto, PublicProfileDto, AdminUserDto } from './account'
