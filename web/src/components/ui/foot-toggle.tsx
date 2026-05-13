import { Footprints } from 'lucide-react'

interface FootToggleProps {
  value: boolean // true = SF (strong foot), false = WF (weak foot)
  onChange: () => void
  disabled?: boolean
}

export function FootToggle({ value, onChange, disabled = false }: FootToggleProps) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={value}
      onClick={onChange}
      disabled={disabled}
      className={`flex items-center gap-1 select-none ${disabled ? 'opacity-40 cursor-not-allowed' : 'cursor-pointer'}`}
    >
      <span className={`text-[10px] font-semibold transition-colors ${value ? 'text-gray-300' : 'text-indigo-600'}`}>WF</span>
      <span className={`relative inline-flex w-7 h-3.5 rounded-full border transition-colors ${value ? 'bg-indigo-100 border-indigo-300' : 'bg-gray-100 border-gray-300'}`}>
        <span className={`absolute top-0 w-3.5 h-3.5 rounded-full flex items-center justify-center shadow-sm transition-transform duration-150 ${value ? 'translate-x-3.5 bg-indigo-500' : 'translate-x-0 bg-gray-400'}`}>
          <Footprints className="w-2 h-2 text-white" />
        </span>
      </span>
      <span className={`text-[10px] font-semibold transition-colors ${value ? 'text-indigo-600' : 'text-gray-300'}`}>SF</span>
    </button>
  )
}
