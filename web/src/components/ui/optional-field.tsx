import { Label } from '@/components/ui/label'

interface OptionalFieldProps {
  label: string
  enabled: boolean
  onToggle: (enabled: boolean) => void
  disabled?: boolean
  className?: string
  children: React.ReactNode
}

/**
 * Wraps a field with an enable/disable checkbox. When disabled, the field
 * is hidden entirely and its value is meant to be sent as null/empty
 * rather than a specific number — the caller decides what "off" means for
 * its own field, this component only controls visibility.
 */
export function OptionalField({ label, enabled, onToggle, disabled = false, className, children }: OptionalFieldProps) {
  return (
    <div className={className ?? 'space-y-1'}>
      <div className="flex items-center justify-between">
        <Label className={disabled ? 'text-gray-400' : ''}>{label}</Label>
        <input
          type="checkbox"
          checked={enabled}
          disabled={disabled}
          onChange={(e) => onToggle(e.target.checked)}
          className="h-4 w-4 rounded border-gray-300 text-indigo-600 disabled:opacity-50"
        />
      </div>
      {enabled && <div className="mt-1">{children}</div>}
    </div>
  )
}
