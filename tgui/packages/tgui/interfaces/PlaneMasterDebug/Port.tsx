import { Button, Stack } from 'tgui/components';
import { classes } from 'common/react';
import { usePopper } from 'react-popper';
import { useState, useRef, useCallback, useEffect } from 'react';
import { createPortal } from 'react-dom';

import { useBackend } from '../../backend';
import { BlendColors, type Filter, type Plane, type Relay } from './types';
import { usePlaneDebugContext } from './usePlaneDebug';

export type PortProps = {
  connection: Filter | Relay;
  source?: boolean;
  target_ref: (element: HTMLElement) => void;
};

export const Port = (props: PortProps) => {
  const { connection, source, target_ref } = props;
  const { act } = useBackend();
  const { setConnectionHighlight, zoomToX, setZoomToX, zoomToY, setZoomToY } =
    usePlaneDebugContext();

  const sourcePlane: Plane = (
    source ? connection.source : connection.target
  ) as Plane;
  const connectedPlane: Plane = (
    source ? connection.target : connection.source
  ) as Plane;

  // --- Popper + popup state ---
  const [isOpen, setIsOpen] = useState(false);
  const [referenceElement, setReferenceElement] = useState<HTMLElement | null>(
    null
  );
  const [popperElement, setPopperElement] = useState<HTMLElement | null>(null);

  const { styles, attributes } = usePopper(referenceElement, popperElement, {
    placement: 'bottom',
    modifiers: [
      {
        name: 'offset',
        options: {
          offset: [0, 8],
        },
      },
      {
        name: 'preventOverflow',
        options: {
          padding: 8,
        },
      },
    ],
  });

  // --- Handle hover open/close ---
  const handleMouseEnter = useCallback(() => setIsOpen(true), []);
  const handleMouseLeave = useCallback(() => setIsOpen(false), []);

  // --- Internal ref for the span that target_ref points to ---
  const spanRef = useRef<HTMLSpanElement>(null);

  // --- Forward the span ref to parent via target_ref ---
  useEffect(() => {
    if (spanRef.current) {
      target_ref(spanRef.current);
    }
  }, [target_ref]);

  // --- Popup content (same as original Floating's content) ---
  const popupContent = (
    <Stack fill vertical>
      <Stack.Item>Connected to {connectedPlane.name}</Stack.Item>
      {!!(connection.blend_mode !== undefined) && (
        <Stack.Item>Blend mode: {connection.blend_mode}</Stack.Item>
      )}
      {!!('type' in connection) && (
        <Stack.Item>Filter type: {connection.type}</Stack.Item>
      )}
      <Button
        color="bad"
        width="120px"
        onClick={() => {
          if ('type' in connection) {
            act('disconnect_filter', {
              target: connection.target?.plane,
              name: connection.name,
            });
          } else {
            act('disconnect_relay', {
              source: connection.source?.plane,
              target: connection.target?.plane,
            });
          }
        }}
      >
        Delete connection
      </Button>
    </Stack>
  );

  return (
    <>
      {/* Trigger element: a div (replaces Box to allow ref) */}
      <div
        ref={setReferenceElement}
        className={classes(['ObjectComponent__Port'])}
        style={{ textAlign: 'center' }}
        onMouseEnter={handleMouseEnter}
        onMouseLeave={handleMouseLeave}
        onDoubleClick={() => {
          setZoomToX(
            connectedPlane.position.x +
              (zoomToX === connectedPlane.position.x ? 0.1 : 0)
          );
          setZoomToY(
            connectedPlane.position.y +
              (zoomToY === connectedPlane.position.y ? 0.1 : 0)
          );
        }}
      >
        <svg
          style={{
            width: '100%',
            height: '100%',
          }}
          viewBox="0, 0, 100, 100"
        >
          <circle
            stroke={connection.node_color}
            strokeDasharray={`${100 * Math.PI}`}
            strokeDashoffset={-100 * Math.PI}
            className={`color-stroke-${connection.node_color}`}
            strokeWidth="50px"
            cx="50"
            cy="50"
            r="50"
            fillOpacity="0"
            transform="rotate(90, 50, 50)"
          />
          <circle
            cx="50"
            cy="50"
            r="50"
            className={`color-fill-${connection.node_color}`}
          />
          <circle
            cx="50"
            cy="50"
            r="25"
            className={`color-fill-${BlendColors[connection.blend_mode || 'BLEND_DEFAULT'] || connection.node_color}`}
          />
        </svg>
        <span ref={spanRef} className="ObjectComponent__PortPos" />
      </div>

      {/* Popup portalled to body */}

      {/* Popup portalled to body */}

      {isOpen &&
        createPortal(
          <div
            ref={setPopperElement}
            style={{
              ...styles.popper,
              backgroundColor: '#202020', // dark background
              color: '#ffffff', // white text
              padding: '8px 12px',
              borderRadius: '4px',
              boxShadow: '0 2px 8px rgba(0,0,0,0.3)',
              zIndex: 1000,
              fontSize: '12px',
              maxWidth: '250px',
            }}
            {...attributes.popper}
            className="Tooltip__Port" // keep if it adds more styling
          >
            {popupContent}
          </div>,
          document.body
        )}
    </>
  );
};
