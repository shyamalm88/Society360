import React, { useState, useMemo } from 'react';
import { useNavigate } from 'react-router-dom';
import { useMutation } from '@tanstack/react-query';
import {
  Building2,
  MapPin,
  Layers,
  Home,
  Check,
  ChevronRight,
  ChevronLeft,
  Plus,
  Trash2,
  Loader2,
  Settings2,
  Eye,
  ChevronDown,
  ChevronUp,
} from 'lucide-react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Badge } from '@/components/ui/badge';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { Checkbox } from '@/components/ui/checkbox';
import {
  Collapsible,
  CollapsibleContent,
  CollapsibleTrigger,
} from '@/components/ui/collapsible';
import { societiesApi } from '@/lib/api';
import { cn } from '@/lib/utils';

const STEPS = [
  { id: 1, title: 'Basic Info', icon: Building2 },
  { id: 2, title: 'Structure', icon: Layers },
  { id: 3, title: 'Review', icon: Check },
];

const STRUCTURE_TYPES = [
  { value: 'apartment', label: 'Apartment Building', description: 'Multi-story buildings with floors and flats' },
  { value: 'villa', label: 'Villa Community', description: 'Individual houses/villas without floors' },
  { value: 'rowhouse', label: 'Row Houses', description: 'Connected houses in a row' },
  { value: 'mixed', label: 'Mixed Development', description: 'Combination of apartments and villas' },
];

const NAMING_STRATEGIES = [
  { value: 'floor_unit', label: 'Floor-Unit (101, 102, 201...)' },
  { value: 'block_prefixed', label: 'Block Prefixed (A-101, B-202...)' },
  { value: 'alpha_prefix', label: 'Alphabetic Prefix (AA-01, AB-02, BA-01...)' },
  { value: 'simple_sequential', label: 'Simple Sequential (1, 2, 3...)' },
  { value: 'custom', label: 'Custom Format' },
];

const UNIT_TYPES = [
  { value: 'simplex', label: 'Simplex (Single Floor)' },
  { value: 'duplex', label: 'Duplex (2 Floors)' },
  { value: 'triplex', label: 'Triplex (3 Floors)' },
  { value: 'penthouse', label: 'Penthouse' },
  { value: 'villa', label: 'Villa' },
  { value: 'rowhouse', label: 'Row House' },
  { value: 'studio', label: 'Studio' },
];

const BHK_OPTIONS = [
  { value: '1', label: '1 BHK' },
  { value: '1.5', label: '1.5 BHK' },
  { value: '2', label: '2 BHK' },
  { value: '2.5', label: '2.5 BHK' },
  { value: '3', label: '3 BHK' },
  { value: '3.5', label: '3.5 BHK' },
  { value: '4', label: '4 BHK' },
  { value: '4+', label: '4+ BHK' },
];

const FLOOR_START_OPTIONS = [
  { value: 'LG', label: 'Lower Ground (LG)' },
  { value: 'G', label: 'Ground (G)' },
  { value: '1', label: '1st Floor' },
];

const SKIP_NUMBER_PRESETS = [
  { value: 'none', label: 'None - Use all numbers' },
  { value: '13', label: 'Skip 13 (Western)' },
  { value: '4', label: 'Skip 4 (Chinese - sounds like death)' },
  { value: '4,13', label: 'Skip 4 & 13' },
  { value: '4,13,14', label: 'Skip 4, 13 & 14' },
  { value: 'custom', label: 'Custom...' },
];

// Helper: Check if a number contains any of the skip numbers
function containsSkipNumber(num, skipNumbers) {
  if (!skipNumbers || skipNumbers.length === 0) return false;
  const numStr = num.toString();
  return skipNumbers.some(skip => numStr.includes(skip.toString()));
}

// Helper: Get next valid number (skipping unlucky numbers)
function getNextValidNumber(current, skipNumbers, maxIterations = 100) {
  let num = current;
  let iterations = 0;
  while (containsSkipNumber(num, skipNumbers) && iterations < maxIterations) {
    num++;
    iterations++;
  }
  return num;
}

// Parse skip numbers from preset or custom string
function parseSkipNumbers(skipPreset, customSkipNumbers) {
  if (skipPreset === 'none' || !skipPreset) return [];
  if (skipPreset === 'custom') {
    if (!customSkipNumbers) return [];
    return customSkipNumbers.split(',').map(n => n.trim()).filter(n => n && !isNaN(n));
  }
  return skipPreset.split(',').map(n => n.trim());
}

// Generate alphabetic prefix for floor (AA, AB, AC... AZ, BA, BB... ZZ)
function getAlphaPrefix(floorIndex, startPrefix = 'AA') {
  // Parse starting prefix (e.g., 'AA' -> [0, 0], 'AZ' -> [0, 25])
  const startFirst = startPrefix.charCodeAt(0) - 65; // A=0, B=1, etc.
  const startSecond = startPrefix.charCodeAt(1) - 65;

  // Calculate total position
  const totalStart = startFirst * 26 + startSecond;
  const totalPosition = totalStart + floorIndex;

  // Convert back to letters
  const firstLetter = String.fromCharCode(65 + Math.floor(totalPosition / 26) % 26);
  const secondLetter = String.fromCharCode(65 + totalPosition % 26);

  return `${firstLetter}${secondLetter}`;
}

// Generate flat names based on configuration
function generateFlatNames(block) {
  const flats = [];
  const {
    name: blockName,
    structureType,
    namingStrategy,
    floors = 1,
    unitsPerFloor = 1,
    floorStart = '1',
    customPrefix = '',
    customSuffix = '',
    separator = '-',
    unitType = 'simplex',
    bhk = '2',
    squareFeet = '',
    hasServiceQuarter = false,
    hasCoveredParking = false,
    skipNumberPreset = 'none',
    customSkipNumbers = '',
  } = block;

  const skipNumbers = parseSkipNumbers(skipNumberPreset, customSkipNumbers);

  // For villas/rowhouses, no floors
  if (structureType === 'villa' || structureType === 'rowhouse') {
    let unitNum = 1;
    for (let i = 0; i < unitsPerFloor; i++) {
      // Skip unlucky unit numbers
      unitNum = getNextValidNumber(unitNum, skipNumbers);

      let flatNumber;
      switch (namingStrategy) {
        case 'block_prefixed':
          flatNumber = `${blockName}${separator}${unitNum}`;
          break;
        case 'custom':
          flatNumber = `${customPrefix}${unitNum}${customSuffix}`;
          break;
        default:
          flatNumber = `${unitNum}`;
      }
      flats.push({
        flatNumber,
        floor: null,
        unitType,
        bhk,
        squareFeet: squareFeet ? parseInt(squareFeet) : null,
        hasServiceQuarter,
        hasCoveredParking,
      });
      unitNum++;
    }
    return flats;
  }

  // For apartments with floors
  let displayFloor = floorStart === 'LG' ? 0 : floorStart === 'G' ? 0 : parseInt(floorStart);

  for (let floorIndex = 0; floorIndex < floors; floorIndex++) {
    let floorLabel;
    let floorNum;

    if (floorStart === 'LG') {
      if (floorIndex === 0) {
        floorLabel = 'LG';
        floorNum = 'LG';
      } else if (floorIndex === 1) {
        floorLabel = 'G';
        floorNum = 'G';
      } else {
        // Skip unlucky floor numbers
        displayFloor = getNextValidNumber(floorIndex - 1, skipNumbers);
        floorLabel = displayFloor.toString();
        floorNum = displayFloor;
      }
    } else if (floorStart === 'G') {
      if (floorIndex === 0) {
        floorLabel = 'G';
        floorNum = 'G';
      } else {
        // Skip unlucky floor numbers
        displayFloor = getNextValidNumber(floorIndex, skipNumbers);
        floorLabel = displayFloor.toString();
        floorNum = displayFloor;
      }
    } else {
      // Skip unlucky floor numbers
      displayFloor = getNextValidNumber(floorIndex + parseInt(floorStart), skipNumbers);
      floorLabel = displayFloor.toString();
      floorNum = displayFloor;
    }

    // For each unit on this floor
    let unitNum = 1;
    for (let unitIndex = 0; unitIndex < unitsPerFloor; unitIndex++) {
      // Skip unlucky unit numbers
      unitNum = getNextValidNumber(unitNum, skipNumbers);

      let flatNumber;
      const unitStr = unitNum.toString().padStart(2, '0');

      switch (namingStrategy) {
        case 'floor_unit':
          if (floorLabel === 'LG' || floorLabel === 'G') {
            flatNumber = `${floorLabel}${separator}${unitStr}`;
          } else {
            flatNumber = `${floorNum}${separator}${unitStr}`;
          }
          break;
        case 'block_prefixed':
          if (floorLabel === 'LG' || floorLabel === 'G') {
            flatNumber = `${blockName}${separator}${floorLabel}${separator}${unitStr}`;
          } else {
            flatNumber = `${blockName}${separator}${floorNum}${separator}${unitStr}`;
          }
          break;
        case 'alpha_prefix':
          // Use alphabetic prefix based on floor (AA, AB, AC... AZ, BA, BB...)
          const alphaPrefix = getAlphaPrefix(floorIndex, customPrefix || 'AA');
          flatNumber = `${alphaPrefix}${separator}${unitStr}`;
          break;
        case 'simple_sequential':
          let seqNum = (floorIndex * unitsPerFloor) + unitIndex + 1;
          seqNum = getNextValidNumber(seqNum, skipNumbers);
          flatNumber = seqNum.toString();
          break;
        case 'custom':
          if (floorLabel === 'LG' || floorLabel === 'G') {
            flatNumber = `${customPrefix}${floorLabel}${separator}${unitStr}${customSuffix}`;
          } else {
            flatNumber = `${customPrefix}${floorNum}${separator}${unitStr}${customSuffix}`;
          }
          break;
        default:
          flatNumber = `${floorNum}${separator}${unitStr}`;
      }

      flats.push({
        flatNumber,
        floor: floorLabel,
        unitType,
        bhk,
        squareFeet: squareFeet ? parseInt(squareFeet) : null,
        hasServiceQuarter,
        hasCoveredParking,
      });
      unitNum++;
    }
  }

  return flats;
}

// Block configuration component
function BlockConfig({ block, index, onUpdate, onRemove, canRemove }) {
  const [isAdvancedOpen, setIsAdvancedOpen] = useState(false);
  const [showPreview, setShowPreview] = useState(false);

  const generatedFlats = useMemo(() => generateFlatNames(block), [block]);
  const previewFlats = generatedFlats.slice(0, 12);
  const isVillaType = block.structureType === 'villa' || block.structureType === 'rowhouse';

  return (
    <div className="rounded-lg border p-4 space-y-4">
      {/* Block Header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <Home className="h-5 w-5 text-primary" />
          <span className="font-medium">
            {isVillaType ? 'Section' : 'Block'} {index + 1}
          </span>
          <Badge variant="outline" className="ml-2">
            {generatedFlats.length} units
          </Badge>
        </div>
        {canRemove && (
          <Button variant="ghost" size="icon" onClick={onRemove}>
            <Trash2 className="h-4 w-4 text-destructive" />
          </Button>
        )}
      </div>

      {/* Basic Configuration */}
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
        <div className="space-y-2">
          <Label>{isVillaType ? 'Section Name' : 'Block Name'}</Label>
          <Input
            placeholder={isVillaType ? 'Phase 1' : 'Block A'}
            value={block.name}
            onChange={(e) => onUpdate('name', e.target.value)}
          />
        </div>

        <div className="space-y-2">
          <Label>Structure Type</Label>
          <Select
            value={block.structureType}
            onValueChange={(value) => onUpdate('structureType', value)}
          >
            <SelectTrigger>
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              {STRUCTURE_TYPES.map((type) => (
                <SelectItem key={type.value} value={type.value}>
                  {type.label}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>

        {!isVillaType && (
          <div className="space-y-2">
            <Label>Number of Floors</Label>
            <Input
              type="number"
              min="1"
              max="100"
              value={block.floors}
              onChange={(e) => onUpdate('floors', parseInt(e.target.value) || 1)}
            />
          </div>
        )}

        <div className="space-y-2">
          <Label>{isVillaType ? 'Total Units' : 'Units per Floor'}</Label>
          <Input
            type="number"
            min="1"
            max="50"
            value={block.unitsPerFloor}
            onChange={(e) => onUpdate('unitsPerFloor', parseInt(e.target.value) || 1)}
          />
        </div>
      </div>

      {/* Naming Strategy */}
      <div className="space-y-2">
        <Label>Naming Strategy</Label>
        <Select
          value={block.namingStrategy}
          onValueChange={(value) => onUpdate('namingStrategy', value)}
        >
          <SelectTrigger>
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            {NAMING_STRATEGIES.map((strategy) => (
              <SelectItem key={strategy.value} value={strategy.value}>
                {strategy.label}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>

      {/* Separator - shown for floor_unit, block_prefixed, alpha_prefix, custom */}
      {['floor_unit', 'block_prefixed', 'alpha_prefix', 'custom'].includes(block.namingStrategy) && (
        <div className="grid gap-4 md:grid-cols-3 p-3 bg-muted/50 rounded-lg">
          <div className="space-y-2">
            <Label>Separator</Label>
            <Input
              placeholder="e.g., - or /"
              value={block.separator || '-'}
              onChange={(e) => onUpdate('separator', e.target.value)}
            />
            <p className="text-xs text-muted-foreground">Character between floor/prefix and unit number</p>
          </div>

          {/* Starting Prefix for Alphabetic pattern */}
          {block.namingStrategy === 'alpha_prefix' && (
            <div className="space-y-2">
              <Label>Starting Prefix</Label>
              <Input
                placeholder="AA"
                value={block.customPrefix || 'AA'}
                onChange={(e) => onUpdate('customPrefix', e.target.value.toUpperCase().slice(0, 2))}
                maxLength={2}
              />
              <p className="text-xs text-muted-foreground">2-letter start (AA, AZ, BA...)</p>
            </div>
          )}

          {/* Custom Prefix/Suffix for custom pattern */}
          {block.namingStrategy === 'custom' && (
            <>
              <div className="space-y-2">
                <Label>Prefix</Label>
                <Input
                  placeholder="e.g., A-"
                  value={block.customPrefix || ''}
                  onChange={(e) => onUpdate('customPrefix', e.target.value)}
                />
              </div>
              <div className="space-y-2">
                <Label>Suffix</Label>
                <Input
                  placeholder="e.g., -A"
                  value={block.customSuffix || ''}
                  onChange={(e) => onUpdate('customSuffix', e.target.value)}
                />
              </div>
            </>
          )}
        </div>
      )}

      {/* Advanced Configuration */}
      <Collapsible open={isAdvancedOpen} onOpenChange={setIsAdvancedOpen}>
        <CollapsibleTrigger asChild>
          <Button variant="ghost" className="w-full justify-between">
            <span className="flex items-center gap-2">
              <Settings2 className="h-4 w-4" />
              Advanced Options
            </span>
            {isAdvancedOpen ? (
              <ChevronUp className="h-4 w-4" />
            ) : (
              <ChevronDown className="h-4 w-4" />
            )}
          </Button>
        </CollapsibleTrigger>
        <CollapsibleContent className="space-y-4 pt-4">
          <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
            {!isVillaType && (
              <div className="space-y-2">
                <Label>Starting Floor</Label>
                <Select
                  value={block.floorStart || '1'}
                  onValueChange={(value) => onUpdate('floorStart', value)}
                >
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {FLOOR_START_OPTIONS.map((opt) => (
                      <SelectItem key={opt.value} value={opt.value}>
                        {opt.label}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
            )}

            <div className="space-y-2">
              <Label>Unit Type</Label>
              <Select
                value={block.unitType || 'simplex'}
                onValueChange={(value) => onUpdate('unitType', value)}
              >
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {UNIT_TYPES.map((type) => (
                    <SelectItem key={type.value} value={type.value}>
                      {type.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            <div className="space-y-2">
              <Label>BHK Configuration</Label>
              <Select
                value={block.bhk || '2'}
                onValueChange={(value) => onUpdate('bhk', value)}
              >
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {BHK_OPTIONS.map((opt) => (
                    <SelectItem key={opt.value} value={opt.value}>
                      {opt.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            <div className="space-y-2">
              <Label>Area (sq.ft)</Label>
              <Input
                type="number"
                min="0"
                placeholder="e.g., 1200"
                value={block.squareFeet || ''}
                onChange={(e) => onUpdate('squareFeet', e.target.value)}
              />
            </div>
          </div>

          <div className="flex flex-wrap gap-6">
            <div className="flex items-center space-x-2">
              <Checkbox
                id={`sq-${index}`}
                checked={block.hasServiceQuarter || false}
                onCheckedChange={(checked) => onUpdate('hasServiceQuarter', checked)}
              />
              <Label htmlFor={`sq-${index}`} className="cursor-pointer">
                Has Service Quarter
              </Label>
            </div>

            <div className="flex items-center space-x-2">
              <Checkbox
                id={`parking-${index}`}
                checked={block.hasCoveredParking || false}
                onCheckedChange={(checked) => onUpdate('hasCoveredParking', checked)}
              />
              <Label htmlFor={`parking-${index}`} className="cursor-pointer">
                Has Covered Parking
              </Label>
            </div>
          </div>

          {/* Skip Unlucky Numbers */}
          <div className="p-3 bg-muted/30 rounded-lg space-y-3">
            <Label className="text-sm font-medium">Skip Unlucky Numbers</Label>
            <p className="text-xs text-muted-foreground">
              Some buildings skip floor 13 (Western) or 4 (Chinese culture - sounds like &quot;death&quot;)
            </p>
            <div className="grid gap-4 md:grid-cols-2">
              <div className="space-y-2">
                <Label className="text-xs">Preset</Label>
                <Select
                  value={block.skipNumberPreset || 'none'}
                  onValueChange={(value) => onUpdate('skipNumberPreset', value)}
                >
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {SKIP_NUMBER_PRESETS.map((preset) => (
                      <SelectItem key={preset.value} value={preset.value}>
                        {preset.label}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>

              {block.skipNumberPreset === 'custom' && (
                <div className="space-y-2">
                  <Label className="text-xs">Custom Numbers (comma-separated)</Label>
                  <Input
                    placeholder="e.g., 4, 13, 14, 24"
                    value={block.customSkipNumbers || ''}
                    onChange={(e) => onUpdate('customSkipNumbers', e.target.value)}
                  />
                </div>
              )}
            </div>
          </div>
        </CollapsibleContent>
      </Collapsible>

      {/* Preview */}
      <div className="pt-2 border-t">
        <Button
          variant="ghost"
          size="sm"
          className="w-full justify-between"
          onClick={() => setShowPreview(!showPreview)}
        >
          <span className="flex items-center gap-2">
            <Eye className="h-4 w-4" />
            Preview Generated Units
          </span>
          {showPreview ? (
            <ChevronUp className="h-4 w-4" />
          ) : (
            <ChevronDown className="h-4 w-4" />
          )}
        </Button>

        {showPreview && (
          <div className="mt-3 p-3 bg-muted/50 rounded-lg">
            <div className="flex flex-wrap gap-2">
              {previewFlats.map((flat, i) => (
                <Badge key={i} variant="secondary" className="font-mono">
                  {flat.flatNumber}
                </Badge>
              ))}
              {generatedFlats.length > 12 && (
                <Badge variant="outline">+{generatedFlats.length - 12} more</Badge>
              )}
            </div>
            <p className="text-xs text-muted-foreground mt-2">
              {block.bhk || '2'} BHK • {block.unitType || 'simplex'}
              {block.squareFeet ? ` • ${block.squareFeet} sq.ft` : ''}
              {block.hasServiceQuarter ? ' • SQ' : ''}
              {block.hasCoveredParking ? ' • Parking' : ''}
            </p>
          </div>
        )}
      </div>
    </div>
  );
}

export default function SocietyOnboarding() {
  const navigate = useNavigate();
  const [currentStep, setCurrentStep] = useState(1);
  const [formData, setFormData] = useState({
    name: '',
    city: '',
    address: '',
    blocks: [
      {
        name: 'Block A',
        structureType: 'apartment',
        namingStrategy: 'floor_unit',
        floors: 5,
        unitsPerFloor: 4,
        floorStart: '1',
        unitType: 'simplex',
        bhk: '2',
        squareFeet: '',
        hasServiceQuarter: false,
        hasCoveredParking: false,
        customPrefix: '',
        customSuffix: '',
        separator: '-',
        skipNumberPreset: 'none',
        customSkipNumbers: '',
      },
    ],
  });

  const createSocietyMutation = useMutation({
    mutationFn: async (data) => {
      // Step 1: Create society
      const societyResponse = await societiesApi.create({
        name: data.name,
        city: data.city,
        address: data.address,
      });
      const society = societyResponse.data.data;

      // Step 2: Create structure with generated flats
      const blocksWithFlats = data.blocks.map((block) => ({
        name: block.name,
        flats: generateFlatNames(block),
      }));

      await societiesApi.createStructure(society.id, {
        blocks: blocksWithFlats,
      });

      return society;
    },
    onSuccess: () => {
      navigate('/societies');
    },
  });

  const updateFormData = (field, value) => {
    setFormData((prev) => ({ ...prev, [field]: value }));
  };

  const addBlock = () => {
    const nextLetter = String.fromCharCode(65 + formData.blocks.length);
    const lastBlock = formData.blocks[formData.blocks.length - 1];
    setFormData((prev) => ({
      ...prev,
      blocks: [
        ...prev.blocks,
        {
          name: `Block ${nextLetter}`,
          structureType: lastBlock?.structureType || 'apartment',
          namingStrategy: lastBlock?.namingStrategy || 'floor_unit',
          floors: lastBlock?.floors || 5,
          unitsPerFloor: lastBlock?.unitsPerFloor || 4,
          floorStart: lastBlock?.floorStart || '1',
          unitType: lastBlock?.unitType || 'simplex',
          bhk: lastBlock?.bhk || '2',
          squareFeet: lastBlock?.squareFeet || '',
          hasServiceQuarter: lastBlock?.hasServiceQuarter || false,
          hasCoveredParking: lastBlock?.hasCoveredParking || false,
          customPrefix: '',
          customSuffix: '',
          separator: '-',
          skipNumberPreset: lastBlock?.skipNumberPreset || 'none',
          customSkipNumbers: lastBlock?.customSkipNumbers || '',
        },
      ],
    }));
  };

  const updateBlock = (index, field, value) => {
    setFormData((prev) => ({
      ...prev,
      blocks: prev.blocks.map((block, i) =>
        i === index ? { ...block, [field]: value } : block
      ),
    }));
  };

  const removeBlock = (index) => {
    if (formData.blocks.length > 1) {
      setFormData((prev) => ({
        ...prev,
        blocks: prev.blocks.filter((_, i) => i !== index),
      }));
    }
  };

  const handleSubmit = () => {
    createSocietyMutation.mutate(formData);
  };

  const getTotalFlats = () => {
    return formData.blocks.reduce((total, block) => {
      return total + generateFlatNames(block).length;
    }, 0);
  };

  const canProceed = () => {
    switch (currentStep) {
      case 1:
        return formData.name && formData.city;
      case 2:
        return formData.blocks.length > 0 && formData.blocks.every((b) => b.name);
      default:
        return true;
    }
  };

  return (
    <div className="max-w-4xl mx-auto space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold md:text-3xl">Onboard New Society</h1>
        <p className="text-muted-foreground">
          Set up a new residential society in the system
        </p>
      </div>

      {/* Progress Steps */}
      <div className="flex items-center justify-between">
        {STEPS.map((step, index) => {
          const StepIcon = step.icon;
          const isActive = currentStep === step.id;
          const isCompleted = currentStep > step.id;

          return (
            <React.Fragment key={step.id}>
              <div className="flex items-center gap-2">
                <div
                  className={cn(
                    'flex h-10 w-10 items-center justify-center rounded-full border-2 transition-colors',
                    isActive
                      ? 'border-primary bg-primary text-primary-foreground'
                      : isCompleted
                      ? 'border-primary bg-primary/10 text-primary'
                      : 'border-muted bg-muted text-muted-foreground'
                  )}
                >
                  {isCompleted ? (
                    <Check className="h-5 w-5" />
                  ) : (
                    <StepIcon className="h-5 w-5" />
                  )}
                </div>
                <span
                  className={cn(
                    'hidden md:block text-sm font-medium',
                    isActive ? 'text-primary' : 'text-muted-foreground'
                  )}
                >
                  {step.title}
                </span>
              </div>
              {index < STEPS.length - 1 && (
                <div
                  className={cn(
                    'flex-1 h-0.5 mx-2',
                    currentStep > step.id ? 'bg-primary' : 'bg-muted'
                  )}
                />
              )}
            </React.Fragment>
          );
        })}
      </div>

      {/* Step Content */}
      <Card>
        <CardHeader>
          <CardTitle>
            {currentStep === 1 && 'Society Information'}
            {currentStep === 2 && 'Building Structure'}
            {currentStep === 3 && 'Review & Create'}
          </CardTitle>
          <CardDescription>
            {currentStep === 1 && 'Enter the basic details of the society'}
            {currentStep === 2 && 'Configure blocks, naming conventions, and unit properties'}
            {currentStep === 3 && 'Review the information before creating'}
          </CardDescription>
        </CardHeader>
        <CardContent>
          {/* Step 1: Basic Info */}
          {currentStep === 1 && (
            <div className="space-y-4">
              <div className="space-y-2">
                <Label htmlFor="name">Society Name *</Label>
                <Input
                  id="name"
                  placeholder="e.g., Prestige Lakeside Habitat"
                  value={formData.name}
                  onChange={(e) => updateFormData('name', e.target.value)}
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="city">City *</Label>
                <Input
                  id="city"
                  placeholder="e.g., Bengaluru"
                  value={formData.city}
                  onChange={(e) => updateFormData('city', e.target.value)}
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="address">Full Address</Label>
                <Input
                  id="address"
                  placeholder="e.g., Whitefield, Bengaluru 560066"
                  value={formData.address}
                  onChange={(e) => updateFormData('address', e.target.value)}
                />
              </div>
            </div>
          )}

          {/* Step 2: Structure Builder */}
          {currentStep === 2 && (
            <div className="space-y-4">
              {formData.blocks.map((block, index) => (
                <BlockConfig
                  key={index}
                  block={block}
                  index={index}
                  onUpdate={(field, value) => updateBlock(index, field, value)}
                  onRemove={() => removeBlock(index)}
                  canRemove={formData.blocks.length > 1}
                />
              ))}

              <Button variant="outline" onClick={addBlock} className="w-full">
                <Plus className="mr-2 h-4 w-4" />
                Add Another Block / Section
              </Button>

              <div className="rounded-lg bg-primary/5 border border-primary/20 p-4 text-center">
                <p className="text-sm text-muted-foreground">Total Units</p>
                <p className="text-3xl font-bold text-primary">{getTotalFlats()}</p>
              </div>
            </div>
          )}

          {/* Step 3: Review */}
          {currentStep === 3 && (
            <div className="space-y-6">
              <div className="rounded-lg border p-4 space-y-3">
                <div className="flex items-center gap-2 text-muted-foreground">
                  <Building2 className="h-4 w-4" />
                  <span className="text-sm">Society</span>
                </div>
                <p className="text-xl font-semibold">{formData.name}</p>
                <div className="flex items-center gap-2 text-muted-foreground">
                  <MapPin className="h-4 w-4" />
                  <span>{formData.city}</span>
                </div>
                {formData.address && (
                  <p className="text-sm text-muted-foreground">{formData.address}</p>
                )}
              </div>

              <div className="rounded-lg border p-4 space-y-3">
                <div className="flex items-center gap-2 text-muted-foreground">
                  <Layers className="h-4 w-4" />
                  <span className="text-sm">Structure</span>
                </div>
                <div className="space-y-3">
                  {formData.blocks.map((block, index) => {
                    const flats = generateFlatNames(block);
                    const isVilla = block.structureType === 'villa' || block.structureType === 'rowhouse';
                    return (
                      <div
                        key={index}
                        className="rounded bg-muted/50 px-3 py-2 space-y-2"
                      >
                        <div className="flex items-center justify-between">
                          <span className="font-medium">{block.name}</span>
                          <Badge variant="outline">{flats.length} units</Badge>
                        </div>
                        <div className="text-sm text-muted-foreground">
                          {!isVilla && `${block.floors} floors × ${block.unitsPerFloor} units • `}
                          {block.bhk || '2'} BHK • {block.unitType || 'simplex'}
                          {block.squareFeet && ` • ${block.squareFeet} sq.ft`}
                        </div>
                        <div className="flex flex-wrap gap-1">
                          {flats.slice(0, 8).map((flat, i) => (
                            <Badge key={i} variant="secondary" className="font-mono text-xs">
                              {flat.flatNumber}
                            </Badge>
                          ))}
                          {flats.length > 8 && (
                            <Badge variant="outline" className="text-xs">
                              +{flats.length - 8} more
                            </Badge>
                          )}
                        </div>
                        <div className="flex gap-2 text-xs">
                          {block.hasServiceQuarter && (
                            <Badge variant="outline" className="text-xs">Service Quarter</Badge>
                          )}
                          {block.hasCoveredParking && (
                            <Badge variant="outline" className="text-xs">Covered Parking</Badge>
                          )}
                        </div>
                      </div>
                    );
                  })}
                </div>
                <div className="pt-2 border-t flex items-center justify-between">
                  <span className="font-medium">Total</span>
                  <span className="text-lg font-bold text-primary">
                    {formData.blocks.length} Blocks, {getTotalFlats()} Units
                  </span>
                </div>
              </div>

              {createSocietyMutation.error && (
                <div className="rounded-lg bg-destructive/10 border border-destructive/20 p-3 text-sm text-destructive">
                  {createSocietyMutation.error.message || 'Failed to create society'}
                </div>
              )}
            </div>
          )}
        </CardContent>
      </Card>

      {/* Navigation Buttons */}
      <div className="flex items-center justify-between">
        <Button
          variant="outline"
          onClick={() => setCurrentStep((s) => s - 1)}
          disabled={currentStep === 1}
        >
          <ChevronLeft className="mr-2 h-4 w-4" />
          Back
        </Button>

        {currentStep < 3 ? (
          <Button onClick={() => setCurrentStep((s) => s + 1)} disabled={!canProceed()}>
            Next
            <ChevronRight className="ml-2 h-4 w-4" />
          </Button>
        ) : (
          <Button onClick={handleSubmit} disabled={createSocietyMutation.isPending}>
            {createSocietyMutation.isPending ? (
              <>
                <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                Creating...
              </>
            ) : (
              <>
                <Check className="mr-2 h-4 w-4" />
                Create Society
              </>
            )}
          </Button>
        )}
      </div>
    </div>
  );
}
